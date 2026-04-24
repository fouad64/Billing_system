package com.billing.filter;

import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;

/**
 * SPA (Single Page Application) Filter
 * Ensures that deep-linked routes (e.g., /dashboard) are handled by SvelteKit's index.html
 * instead of returning a 404 from Tomcat.
 */
@WebFilter(urlPatterns = "/*")
public class SpaFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        HttpServletRequest req = (HttpServletRequest) request;
        String path = req.getRequestURI().substring(req.getContextPath().length());

        // 1. Allow API calls to pass through to Servlets
        // 2. Allow static assets (_app, images, etc.) to pass through
        // 3. Forward everything else to index.html
        if (path.startsWith("/api/") || 
            path.startsWith("/_app/") || 
            path.contains(".") || 
            path.equals("/")) {
            chain.doFilter(request, response);
        } else {
            // Forward to index.html to let SvelteKit handle the route
            request.getRequestDispatcher("/index.html").forward(request, response);
        }
    }

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {}

    @Override
    public void destroy() {}
}
