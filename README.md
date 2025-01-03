# abimania-shop
 
### Developer Environment

#### Prerequisities:
- install `mkcert` and `nss`
- add to /etc/hosts
```
127.0.0.1 abimania.local
127.0.0.1 tickets.abimania.local
127.0.0.1 grafana.abimania.local
127.0.0.1 hd.abimania.local
```

#### Start
```
export ENVIRONMENT=development
make install-ssl-certificates
make dev
```

### Prod start

```
export ENVIRONMENT=production
make prod
make pretix-addcron
```