# Microservicios AWS - Infraestructura y CI/CD

## 📋 Descripción

Proyecto de microservicios con infraestructura AWS completa y CI/CD automatizado.

### Microservicios

- **ms-users** (Puerto 8081) - Gestión de usuarios
- **ms-orders** (Puerto 8082) - Gestión de órdenes
- **ms-notifications** (Puerto 8083) - Gestión de notificaciones

### Infraestructura AWS

- **Application Load Balancer** - Distribuye tráfico a los microservicios
- **Auto Scaling Groups** - Escala automáticamente (min: 2, max: 3 instancias por servicio)
- **RDS PostgreSQL** - Base de datos compartida con schemas separados
- **CloudWatch Alarms** - Monitoreo y alertas de CPU
- **Target Groups** - Health checks en `/actuator/health`

## 🚀 Setup Inicial

### 1. Configurar Secrets en GitHub

Ve a Settings → Secrets and variables → Actions y agrega:

#### AWS Credentials
```
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_SESSION_TOKEN=your_session_token (si usas AWS Academy)
AWS_REGION=us-east-1
```

#### VPC & Network
```
VPC_ID=vpc-xxxxxxxxx
SUBNET1=subnet-xxxxxxxxx
SUBNET2=subnet-yyyyyyyyy
```

#### Docker Hub
```
DOCKER_HUB_USERNAME=your_dockerhub_username
DOCKER_HUB_TOKEN=your_dockerhub_token
```

#### Database
```
DB_USERNAME=postgres
DB_PASSWORD=your_secure_password
```

### 2. Estructura del Proyecto

```
.
├── services/
│   ├── users/          # ms-users (Spring Boot + PostgreSQL)
│   ├── orders/         # ms-orders (Spring Boot + PostgreSQL)
│   └── notifications/  # ms-notifications (Spring Boot + PostgreSQL)
├── infra/
│   ├── main.tf         # Infraestructura Terraform
│   ├── variables.tf    # Variables de Terraform
│   ├── outputs.tf      # Outputs de Terraform
│   ├── user-data-*.sh  # Scripts de inicialización EC2
│   └── modules/        # Módulos antiguos (no se usan)
├── .github/
│   └── workflows/
│       └── deploy.yml  # CI/CD único
└── instances.txt       # Tracking de instancias AWS
```

## 🔄 Flujo de CI/CD

### Trigger Automático

El workflow se ejecuta automáticamente cuando:
- Se hace push a `main`, `dev`, o `qa`
- Se modifican archivos en `services/`, `infra/`, o `.github/workflows/`

### Proceso

1. **Detectar Cambios**
   - Identifica qué microservicios fueron modificados
   - Compara commits para determinar los servicios afectados

2. **Build & Push Docker**
   - Construye imágenes Docker solo de servicios modificados
   - Pushea a Docker Hub con tags `latest` y `<commit-sha>`
   - Usa cache de GitHub Actions para builds más rápidos

3. **Deploy AWS con Terraform**
   - Aplica infraestructura con Terraform
   - Crea/actualiza ALB, ASGs, RDS, Security Groups
   - Obtiene nombres de Auto Scaling Groups

4. **Refresh Instances**
   - Termina instancias de servicios modificados
   - ASG automáticamente crea nuevas instancias
   - Nuevas instancias descargan imagen Docker actualizada
   - Actualiza `instances.txt` con IDs de instancias actuales

### Manual Trigger

Ejecutar manualmente desde GitHub:
```
Actions → CI/CD Microservicios → Run workflow
```

Esto construirá y desplegará TODOS los microservicios.

## 🏗️ Infraestructura Terraform

### Recursos Principales

#### Application Load Balancer
- Nombre: `microservicios-alb`
- Puerto: 80 (HTTP)
- Listener Rules:
  - `/api/users*` → ms-users (puerto 8081)
  - `/api/orders*` → ms-orders (puerto 8082)
  - `/api/notifications*` → ms-notifications (puerto 8083)

#### Auto Scaling Groups
- **ms-users-asg**: min=2, max=3, desired=2
- **ms-orders-asg**: min=2, max=3, desired=2
- **ms-notifications-asg**: min=2, max=3, desired=2

#### RDS PostgreSQL
- Engine: PostgreSQL 16.1
- Instance: db.t3.micro
- Database: `microservices_db`
- Schemas:
  - `users_schema`
  - `orders_schema`
  - `notifications_schema`

#### Health Checks
- Path: `/actuator/health`
- Interval: 30s
- Timeout: 5s
- Healthy threshold: 2
- Unhealthy threshold: 3

#### Auto Scaling Policies
- **Scale UP**: CPU > 70% durante 2 períodos
- **Scale DOWN**: CPU < 30% durante 2 períodos

### Deploy Local de Terraform

```bash
cd infra

# Inicializar
terraform init

# Planificar
terraform plan \
  -var="AWS_REGION=us-east-1" \
  -var="AWS_ACCESS_KEY_ID=xxx" \
  -var="AWS_SECRET_ACCESS_KEY=xxx" \
  -var="AWS_SESSION_TOKEN=xxx" \
  -var="vpc_id=vpc-xxx" \
  -var="subnet1=subnet-xxx" \
  -var="subnet2=subnet-yyy" \
  -var="docker_hub_username=your_username" \
  -var="db_username=postgres" \
  -var="db_password=your_password"

# Aplicar
terraform apply -auto-approve [... same vars ...]

# Ver outputs
terraform output

# Destruir
terraform destroy -auto-approve [... same vars ...]
```

## 📊 Monitoreo

### Verificar Health de Servicios

```bash
# Desde el ALB
curl http://<ALB-DNS>/api/users/actuator/health
curl http://<ALB-DNS>/api/orders/actuator/health
curl http://<ALB-DNS>/api/notifications/actuator/health
```

### Ver Instancias Activas

El archivo `instances.txt` se actualiza automáticamente después de cada deployment y contiene:

```
[ms-users]
i-0123456789abcdef0	InService
i-0123456789abcdef1	InService

[ms-orders]
i-0fedcba9876543210	InService
i-0fedcba9876543211	InService

[ms-notifications]
i-0abcdef0123456789	InService
i-0abcdef012345678a	InService
```

### CloudWatch

Todas las métricas están disponibles en CloudWatch:
- CPU Utilization por ASG
- Network In/Out
- ALB Target Response Time
- ALB Request Count

## 🧪 Testing

### Probar Endpoints

Usa la colección de Postman incluida:
```
Microservicios_Postman_Collection.json
```

O con curl:

```bash
# Obtener DNS del ALB
ALB_URL=$(terraform output -raw alb_url)

# ms-users
curl -X POST $ALB_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'

curl $ALB_URL/api/users

# ms-orders
curl -X POST $ALB_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"total":100.50}'

curl $ALB_URL/api/orders

# ms-notifications
curl -X POST $ALB_URL/api/notifications \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"message":"Test notification","type":"GENERAL"}'

curl $ALB_URL/api/notifications
```

## 🔧 Troubleshooting

### Ver logs de instancias

```bash
# SSH a instancia (necesitas la private key)
terraform output -raw ms_users_private_key > users-key.pem
chmod 400 users-key.pem

# Obtener IP pública de instancia
aws ec2 describe-instances \
  --instance-ids i-xxxxxxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

ssh -i users-key.pem ec2-user@<PUBLIC-IP>

# Ver logs del contenedor
sudo docker logs ms-users
sudo docker logs ms-orders
sudo docker logs ms-notifications
```

### Forzar refresh de instancias

```bash
# Terminar todas las instancias de un servicio
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id i-xxxxxxxxx \
  --no-should-decrement-desired-capacity \
  --region us-east-1

# ASG creará automáticamente una nueva instancia
```

### Verificar Target Groups

```bash
# Ver estado de targets
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

## 📝 Notas Importantes

1. **Costos**: Esta infraestructura tiene costos en AWS:
   - 6 instancias t2.micro (2 por servicio)
   - 1 RDS db.t3.micro
   - 1 Application Load Balancer
   - Data transfer

2. **AWS Academy**: Si usas AWS Academy Learner Lab:
   - Recuerda actualizar `AWS_SESSION_TOKEN` cada 4 horas
   - No uses Multi-AZ para RDS (más caro)
   - Usa `skip_final_snapshot = true` para RDS

3. **Instance Refresh**: El proceso de terminar instancias tarda ~2-3 minutos por instancia. El ASG automáticamente crea nuevas.

4. **Database Schemas**: Cada microservicio usa su propio schema en PostgreSQL para aislamiento lógico.

5. **Health Checks**: Spring Boot Actuator expone `/actuator/health` automáticamente. El ALB lo usa para verificar el estado de las instancias.

## 🎯 Best Practices Implementadas

- ✅ Health checks con Spring Boot Actuator
- ✅ Auto scaling basado en CPU
- ✅ Deregistration delay para zero-downtime deployments
- ✅ Multi-AZ con 2 subnets diferentes
- ✅ Security Groups con principio de mínimo privilegio
- ✅ Schemas de BD separados por microservicio
- ✅ CI/CD optimizado (solo construye lo modificado)
- ✅ Instance tracking para auditoría
- ✅ Docker multi-stage builds para imágenes pequeñas
- ✅ Variables de entorno para configuración

## 📚 Documentación Adicional

- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [AWS Auto Scaling](https://docs.aws.amazon.com/autoscaling/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 🤝 Contribuir

Para agregar un nuevo microservicio:

1. Crear directorio en `services/`
2. Agregar Dockerfile
3. Actualizar `infra/main.tf` con el nuevo servicio
4. Agregar listener rule en ALB
5. Crear user-data script
6. Actualizar workflow en `.github/workflows/deploy.yml`

---

**Hecho con ❤️ para el examen de Microservicios**
