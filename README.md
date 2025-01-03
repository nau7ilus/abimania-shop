# abimania-shop
 
### Dev start

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