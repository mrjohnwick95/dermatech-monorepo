# ETAPA 1: BUILDER
# Usamos Node 20 Alpine (Ligero y Seguro)
FROM node:20-alpine As builder

WORKDIR /usr/src/app

# Copiamos la configuración del Mono-Repo
COPY package*.json ./
COPY nx.json ./
COPY tsconfig.base.json ./

# Instalamos dependencias (Nx requiere esto para construir)
RUN npm ci

# Copiamos todo el código fuente
COPY . .

# Construimos el microservicio Auth
# Nx buscará el proyecto "auth-service" en la configuración
RUN npx nx build auth-service --configuration=production

# ETAPA 2: PRODUCTION
FROM node:20-alpine As production

WORKDIR /usr/src/app

# Traemos solo lo compilado (dist) y las dependencias de producción
COPY --from=builder /usr/src/app/dist/apps/services/core/auth-service ./dist
COPY --from=builder /usr/src/app/node_modules ./node_modules

# Exponemos el puerto definido en NestJS (por defecto 3000)
EXPOSE 3000

# Arrancamos el servicio
CMD ["node", "dist/main"]