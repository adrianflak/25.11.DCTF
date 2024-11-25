terraform {
  # Definicja wymaganego dostawcy (provider) Docker!
  required_providers {
    docker = {
      source  = "kreuzwerker/docker" # Źródło dostawcy Terraform dla Dockera
      version = "~> 2.25"            # Wersja dostawcy Docker
    }
  }
}
# Ustawienie dostawcy Docker
provider "docker" {}

# Sieć do komunikacji pomiędzy kontenerami
data "docker_network" "existing_network" {
  name = "app_network"
}
# Sieć tworzona wtedy kiedy istnieje
resource "docker_network" "app_network" {
  name = "app_network"

  # Tworzenie sieci tylko wtedy, gdy jej brak
  count = length(data.docker_network.existing_network.id) == 0 ? 1 : 0
}
# Wolumin dla MongoDB
resource "docker_volume" "mongo_data" {
    name = "mongo_data"
}

# Pobranie obrazu z DockerHub
resource "docker_image" "mongo" {
    name = "mongo:5.0"
}
# Sprawdzenie czy istnieje kontener Mongo
data "external" "existing_mongo" {
  program = ["bash", "-c", "docker ps -a --filter 'name=mongo' --format '{{.Names}}' | grep -w mongo || echo ''"]
}
# Tworzenie kontenera dla MongoDB, jeśli nie istnieje
resource "docker_container" "mongo" {
    count = data.external.existing_mongo.result == "" ? 1 : 0
    name = "mongo"
    image = docker_image.mongo.name

    ports {
        internal = 27017 # port w kontenerze
        external = 27017 # port w hoście 
    }
    # Podłączenie do sieci 
    networks_advanced {
        #name = docker_network.app_network.name
        name = "app_network"
    }
    # Montowanie woluminu MongoDB
    mounts {
        target = "/data/db"
        source = docker_volume.mongo_data.name
        type = "volume"
    }
} 
# Tworzenie obrazu Dockera dla Nodejs
resource "docker_image" "app_image" {
    name = "node-mongo-app"
    build {
        context = "${path.module}/."
        dockerfile = "Dockerfile"
    }
}
# Tworzenie kontenera dla aplikacji Nodejs
resource "docker_container" "app" {
    name = "app" # Nazwa kontenera
    image = docker_image.app_image.name # Wykorzystanie obrazu z DockerHub
    #image = "${var.docker_image}"

    ports {
        internal = 3000 # port w kontenerze
        external = 3000 # port w hoście
    }
    networks_advanced {
        name = "app_network"
        #name = docker_network.app_network.name
    }
    env = [
        "MONGO_URL=mongodb://mongo:27017/myapp"
    ]
    # Kontener aplikacji nie uruchomi się przed Mongo
    depends_on = [docker_container.mongo]
}


