#!/bin/bash
# Helper script for test environment management
# This avoids warnings from main docker-compose.yml

COMPOSE_FILE="docker-compose.test.yml"

case "$1" in
  up)
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  down)
    docker compose -f "$COMPOSE_FILE" down
    ;;
  ps)
    docker compose -f "$COMPOSE_FILE" ps
    ;;
  logs)
    docker compose -f "$COMPOSE_FILE" logs -f "${2:-}"
    ;;
  restart)
    docker compose -f "$COMPOSE_FILE" restart "${2:-}"
    ;;
  stop)
    docker compose -f "$COMPOSE_FILE" stop
    ;;
  start)
    docker compose -f "$COMPOSE_FILE" start
    ;;
  status)
    echo "📋 Test Environment Status:"
    echo ""
    docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "🌐 Access Points:"
    echo "   - Twenty CRM: http://localhost:3000"
    if [ -f /tmp/ngrok-webhook-url.txt ]; then
      echo "   - ngrok Webhook: $(cat /tmp/ngrok-webhook-url.txt)"
    fi
    ;;
  *)
    echo "Usage: $0 {up|down|ps|logs|restart|stop|start|status}"
    echo ""
    echo "Commands:"
    echo "  up          - Start all test services"
    echo "  down        - Stop and remove all test services"
    echo "  ps          - Show service status"
    echo "  logs [svc]  - Show logs (optionally for specific service)"
    echo "  restart [svc] - Restart services (optionally specific service)"
    echo "  stop        - Stop services"
    echo "  start       - Start services"
    echo "  status      - Show detailed status"
    exit 1
    ;;
esac

