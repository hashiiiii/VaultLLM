locals {
  ecs_cluster_name      = "${var.project_name}-main-cluster"
  ecs_service_name      = "${var.project_name}-webui-service"
  ecs_task_family       = "${var.project_name}-webui-task"
  log_group_name        = "${var.project_name}/ecs/tasks"

  ollama_container_name = "ollama"
  webui_container_name  = "open-webui"

  ollama_volume_name    = "ollama-data"
  ollama_volume_path    = "/root/.ollama"
  webui_volume_name     = "open-webui-data"
  webui_volume_path     = "/app/backend/data"
}
