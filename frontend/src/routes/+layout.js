export const prerender = false;
export const ssr = false;
export const trailingSlash = 'ignore';

/** @type {import('./$types').LayoutLoad} */
export const load = async () => {
    // Dynamic environment detection based on the current URL
    const isDev = typeof window !== 'undefined' && window.location.port === '5173';
    const env = isDev ? 'development' : 'production';
    
    // Always use relative API paths when served from Tomcat (8080)
    // Use localhost:8080 only when developing on 5173
    const apiUrl = isDev ? 'http://localhost:8080' : '';
    
    return { 
        environment: env,
        apiUrl: apiUrl
    };
};
