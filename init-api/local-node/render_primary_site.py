"""Generate a school Caddy vhost from validated enrollment (never enable LAN bypass)."""
import re


def render_primary_site(hostname):
    if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.gbousecurity\.ru', hostname):
        raise ValueError('Invalid school hostname')
    return f'''# Generated public school site. TLS private key remains on this Pi.
{hostname} {{
    encode zstd gzip
    header {{
        -Server
        -Alt-Svc
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy same-origin
    }}
    route {{
        @largeLogin {{
            path /api/v1/auth/login
            header_regexp Content-Length ^0*(819[3-9]|8[2-9][0-9]{{2}}|9[0-9]{{3}}|[1-9][0-9]{{4,}})$
        }}
        handle @largeLogin {{
            header Cache-Control no-store
            respond 413
        }}
        @login path /api/v1/auth/login
        handle @login {{
            request_body {{
                max_size 8KB
            }}
            header Cache-Control no-store
            reverse_proxy 127.0.0.1:8081
        }}
        handle /api/* {{
            request_body {{
                max_size 5MB
            }}
            header Cache-Control no-store
            reverse_proxy 127.0.0.1:8081
        }}
        handle /ready {{
            header Cache-Control no-store
            reverse_proxy 127.0.0.1:8081
        }}
        @private path /local /local/* /docs /docs/* /redoc /openapi.json /.env /.git/*
        handle @private {{
            respond 404
        }}
        @asset path *.js *.mjs *.wasm *.gz *.json *.png *.woff *.woff2 *.ttf
        handle @asset {{
            root * /var/www/gbou-local
            header Cache-Control no-cache
            file_server
        }}
        handle {{
            root * /var/www/gbou-local
            header Cache-Control no-cache
            try_files {{path}} /index.html
            file_server
        }}
    }}
}}
'''
