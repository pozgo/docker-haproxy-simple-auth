### HAProxy Simple Auth

### Environmental Variables

| Envinronmental Variable       | Purpose                              |
|-------------------------------|--------------------------------------|
| `CONF_LISTEN_PORT`            | Port on which we connect to Haproxy  |
| `CONF_DEFAULT_SERVER_NAME`    | server name                          |
| `CONF_DEFAULT_SERVER_ADDRESS` | Usually kube service name            |
| `CONF_DEFAULT_SERVER_PORT`    | port on which app listens `NodePort` |
| `CONF_STATS_USERNAME`         | Stats page authentication            |
| `CONF_STATS_PASSWORD`         | Stats page authentication            |
| `CONF_STATS_URI`              | `URL` on which stats are accessible  |
| `CONF_SIMPLE_AUTH_USERNAME`   | Allowed username                     |
| `CONF_SIMPLE_AUTH_PASSWORD`   |                                      |

**Note: So far only Alpine version available**