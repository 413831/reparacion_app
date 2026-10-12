# Reparatutti 🛠️

Plataforma móvil multiplataforma (Flutter para iOS y Android) y backend cloud-native (Go 1.22+ con Arquitectura Hexagonal) que conecta a clientes con técnicos profesionales verificados en oficios del hogar (Electricidad, Pintura, Gas, Construcción, Flete y Reparación Edilicia).

Incluye validación biométrica de identidad (KYC), chat 1:1 en tiempo real aislado por servicio, compartición protegida de ubicación física y marco legal alineado a la legislación argentina (Ley 25.326 de Protección de Datos Personales y Ley 24.240 de Defensa del Consumidor).

---

## 🚀 Instrucciones de Ejecución

### Prerrequisitos
- **Go 1.22+** instalado.
- **Flutter 3.x / Dart 3.x** instalado con SDK configurado.
- (Opcional) **PostgreSQL 14+** si deseas aplicar la migración SQL física. El backend incluye almacenamiento en memoria automático para pruebas inmediatas sin dependencias externas.

---

### 1. Levantar el Backend (Go)

```bash
# 1. Ingresar al directorio del backend
cd backend

# 2. Descargar dependencias
go mod tidy

# 3. Iniciar el servidor
go run ./cmd/server
```

> El servidor iniciará en `http://localhost:8080` con datos iniciales precargados (*seed*) para pruebas:
> - **Cliente:** `cliente@reparatutti.com` / `Password123!`
> - **Técnico Verificado:** `tecnico.verificado@reparatutti.com` / `Password123!`
> - **Técnico Pendiente KYC:** `tecnico.pendiente@reparatutti.com` / `Password123!`

Para ejecutar la suite de pruebas unitarias:
```bash
go test -v ./...
```

---

### 2. Levantar la Aplicación Móvil (Flutter)

```bash
# 1. Ingresar al directorio móvil
cd mobile

# 2. Instalar paquetes de Flutter
flutter pub get

# 3. Ejecutar en emulador o dispositivo conectado
flutter run
```

Para validar análisis estático y pruebas:
```bash
flutter analyze
flutter test
```

---

## 📐 Características Generales y Diagramas

### Flujo Principal del Servicio

```mermaid
sequenceDiagram
    autonumber
    actor C as Cliente
    participant App as Reparatutti App
    participant API as Backend (Go)
    actor T as Técnico Verificado

    C->>App: Publica solicitud con categoría, fotos y fecha
    App->>API: POST /api/v1/jobs
    T->>API: Aplica con presupuesto (requiere KYC verificado)
    C->>App: Evalúa postulantes y acepta presupuesto
    App->>API: POST /api/v1/jobs/:id/accept/:proposal_id
    API-->>App: Desbloquea sala de chat privado 1:1 (WebSocket)
    C->>App: Pulsa "Enviar dirección exacta" en el chat
    App->>T: Envía tarjeta con vista previa de mapa y coordenadas
    Note over C,T: El técnico realiza el servicio en el domicilio
    C->>App: Marca servicio completado y califica (1 a 5 estrellas)
    App->>API: POST /api/v1/jobs/:id/review
    API->>API: Recalcula rating acumulativo: ((actual * N) + score) / (N + 1)
```

---

### Arquitectura Hexagonal del Backend

```mermaid
graph TD
    subgraph "Adaptadores de Entrada (Primary Adapters)"
        HTTP["REST Handlers (Gin)"]
        WS["WebSocket Hub (1:1 Chat)"]
        MW["Middlewares (JWT, RBAC, Rate Limiter 80 RPM)"]
    end

    subgraph "Núcleo de Negocio (Core Domain & Ports)"
        Services["Servicios de Dominio<br>(KYCService, JobService, ReviewService)"]
        Domain["Entidades y Reglas<br>(User, Job, Proposal, Message, Review)"]
        Ports["Puertos e Interfaces<br>(IdentityVerifier, Repositories)"]
    end

    subgraph "Adaptadores de Salida (Secondary Adapters)"
        Repo["PostgreSQL / In-Memory Repo"]
        MockKYC["Mock IdentityVerifier<br>(RENAPER / Biometría Facial)"]
    end

    HTTP --> Services
    WS --> Services
    MW --> HTTP
    Services --> Domain
    Services --> Ports
    Ports --> Repo
    Ports --> MockKYC
```

---

### Resumen de Funcionalidades Clave

| Módulo | Descripción |
| :--- | :--- |
| **Validación KYC** | Validación obligatoria para técnicos (DNI frente/dorso + selfie con prueba de vida) y biometría facial para clientes. Técnicos no verificados no pueden postularse. |
| **Privacidad de Ubicación** | La dirección exacta no se expone públicamente; el cliente la comparte explícitamente dentro del chat tras aceptar la propuesta. |
| **Marco Legal Argentino** | Flujo de consentimiento para **Ley 25.326** (Protección de Datos Personales), ejercicio de **Derechos ARCO** (AAIP) y **Ley 24.240** (Defensa del Consumidor). |
| **Chat en Tiempo Real** | Mensajería 1:1 en WebSocket aislada por `job_id` con tarjetas de vista previa de mapa y coordenadas geográficas. |
| **Diseño y UX** | Paleta personalizada (Mostaza, Negro, Blanco), soporte completo para **Light & Dark Mode** y **Skeleton Loaders (Shimmer)** para evitar bloqueos de interfaz. |