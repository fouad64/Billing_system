package com.billing.filter;

import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpServletResponseWrapper;
import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Optional;
import java.util.stream.Stream;

@WebFilter(urlPatterns = "/*")
public class HtmlInjectionFilter implements Filter {

    private String cachedCssTag = null;
    private long lastBuildTime = 0;

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;
        String path = req.getRequestURI().substring(req.getContextPath().length());

        if (path.startsWith("/api/") || path.startsWith("/_app/") || (path.contains(".") && !path.endsWith(".html"))) {
            chain.doFilter(request, response);
            return;
        }

        String cssTag = getCssTag(req.getServletContext());
        CharResponseWrapper wrapper = new CharResponseWrapper(res);
        chain.doFilter(request, wrapper);

        byte[] responseBytes = wrapper.getByteArray();
        String html = new String(responseBytes, "UTF-8");
        
        if (html.contains("</head>")) {
            System.out.println("[HtmlInjectionFilter] Injecting CSS into: " + path);
            html = html.replace("</head>", cssTag + "\n</head>");
            byte[] finalBytes = html.getBytes("UTF-8");
            res.setContentType("text/html; charset=UTF-8");
            res.setContentLength(finalBytes.length);
            res.getOutputStream().write(finalBytes);
        } else {
            res.getOutputStream().write(responseBytes);
        }
    }

    private synchronized String getCssTag(ServletContext context) {
        String assetsPath = context.getRealPath("/_app/immutable/assets");
        if (assetsPath == null) return cachedCssTag != null ? cachedCssTag : "";

        File assetsDir = new File(assetsPath);
        if (!assetsDir.exists()) return "";

        if (assetsDir.lastModified() > lastBuildTime) {
            try (Stream<Path> walk = Files.walk(Paths.get(assetsPath))) {
                Optional<String> cssFile = walk
                        .filter(Files::isRegularFile)
                        .map(Path::getFileName)
                        .map(Path::toString)
                        .filter(name -> name.endsWith(".css"))
                        .sorted((a, b) -> {
                            if (a.startsWith("0.") && !b.startsWith("0.")) return -1;
                            if (!a.startsWith("0.") && b.startsWith("0.")) return 1;
                            return a.compareTo(b);
                        })
                        .findFirst();

                if (cssFile.isPresent()) {
                    cachedCssTag = "<link rel=\"stylesheet\" href=\"/_app/immutable/assets/" + cssFile.get() + "\">";
                    System.out.println("[HtmlInjectionFilter] Found CSS: " + cssFile.get());
                    lastBuildTime = assetsDir.lastModified();
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return cachedCssTag != null ? cachedCssTag : "";
    }

    private static class CharResponseWrapper extends HttpServletResponseWrapper {
        private ByteArrayOutputStream baos = new ByteArrayOutputStream();
        private ServletOutputStream sos = new ServletOutputStream() {
            @Override public boolean isReady() { return true; }
            @Override public void setWriteListener(WriteListener writeListener) {}
            @Override public void write(int b) throws IOException { baos.write(b); }
        };
        private PrintWriter pw = new PrintWriter(new OutputStreamWriter(baos, "UTF-8"));

        public CharResponseWrapper(HttpServletResponse response) throws UnsupportedEncodingException {
            super(response);
        }

        @Override public ServletOutputStream getOutputStream() { return sos; }
        @Override public PrintWriter getWriter() { return pw; }
        public byte[] getByteArray() { 
            pw.flush();
            return baos.toByteArray(); 
        }
    }

    @Override public void init(FilterConfig filterConfig) {}
    @Override public void destroy() {}
}
