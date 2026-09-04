# Statik site; sunucuda "derleme" nginx imajina uc dosya kopyalamaktan ibaret.
FROM nginx:1.29-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html gizlilik.html style.css /usr/share/nginx/html/

EXPOSE 80
