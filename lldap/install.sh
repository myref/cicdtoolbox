#!/bin/bash

print_random () {
  LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32
}

LLDAP_JWT_SECRET=$(print_random)
LLDAP_KEY_SEED=$(print_random)

