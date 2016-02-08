# Targets:
#   all		Sets up CA and server
#   XXX install_keys  Run on a Linux host after extracting the tarball; specify DEST
#   		  (Don't forget to install and modify the config file.)
#
# The following variables may/must be present on the command line:
#   SERVER_ID
#   KEY_DEPT (optional; specifies organizationalUnitName and alters config file name)
#   CN (optional; specifies commonName)
#   KEY_DIR (optional)
#   KEY_CONFIG (optional)
#   CA_ARGS (optional; can be used to pass "-batch")
#   
# The following environment variables may/must be present:
#   KEY_ORG (mandatory)
#   KEY_SIZE (optional; do not change after CA is built; edit server/staff.conf)
#
# TO-DO:
#   + add 'remove' target; runs "rm -rf keys/$(CLIENT).* clients/.$(CLIENT)_*stamp clients/$(CLIENT)"
#   + make 'remove' target depnd on 'revoke' target

# == Setup ==
.EXPORT_ALL_VARIABLES:

# must be a single word
SERVER = server
SERVER_ID = $(SERVER)

DEST = /tmp/keys

KEY_CONFIG = openssl.cnf
KEY_DIR = keys
# These might be overriden by an environment variable
KEY_SIZE ?= 2048
KEY_DEPT ?= 
CN ?= 

SERVER_KEY_FILES = $(KEY_DIR)/ca.crt $(KEY_DIR)/$(SERVER_ID).crt $(KEY_DIR)/$(SERVER_ID).key $(KEY_DIR)/dh$(KEY_SIZE).pem


# *** TARGETS ***
.PHONY: cert
# make sure all required files exist
cert: $(KEY_DIR)/ca.key $(SERVER_KEY_FILES)


# == Server ==
$(KEY_DIR)/dh$(KEY_SIZE).pem:
	openssl dhparam -out $(KEY_DIR)/dh$(KEY_SIZE).pem $(KEY_SIZE)

$(KEY_DIR)/$(SERVER_ID).crt: $(KEY_DIR)/$(SERVER_ID).csr $(KEY_DIR)/ca.crt $(KEY_DIR)/ca.key | $(KEY_DIR)/dh$(KEY_SIZE).pem 
	openssl ca -config $(KEY_CONFIG) $(CA_ARGS) \
	  -extensions usr_cert -days 3650 \
	  -in $(KEY_DIR)/$(SERVER_ID).csr -out $(KEY_DIR)/$(SERVER_ID).crt

$(KEY_DIR)/$(SERVER_ID).key $(KEY_DIR)/$(SERVER_ID).csr: $(KEY_DIR)/ca.key
	CN="$(SERVER_ID)" openssl req -config $(KEY_CONFIG) $(REQ_ARGS) \
	  -new -extensions usr_cert -out $(KEY_DIR)/$(SERVER_ID).csr \
	  -newkey rsa:$(KEY_SIZE) -keyout $(KEY_DIR)/$(SERVER_ID).key -nodes
	chmod 0600 $(KEY_DIR)/$(SERVER_ID).key


# == distribution archives ==
.phony: tarball

tarball: $(SERVER_ID).tar.gz
$(SERVER_ID).tar.gz: $(SERVER_KEY_FILES) servers/$(SERVER_ID)_*.conf
	tar czhf $@ -C servers $$(cd servers ; ls $(SERVER_ID)_[0-9]*.conf) -C .. \
	            scripts/routing_on.up $(SERVER_KEY_FILES)


# == CA ==
# Note: $(REQ_ARGS) is not used
$(KEY_DIR)/ca.crt: | $(KEY_DIR)/ca.key
$(KEY_DIR)/ca.key: | $(KEY_DIR)/index.txt $(KEY_DIR)/serial
	@echo Creating CA key and certificate
	openssl req -config $(KEY_CONFIG) \
	  -new -x509 -days 3650 -out $(KEY_DIR)/ca.crt \
	  -newkey rsa:$(KEY_SIZE) -keyout $(KEY_DIR)/ca.key -nodes
	chmod 0600 $(KEY_DIR)/ca.key

$(KEY_DIR)/index.txt: | $(KEY_DIR)
	touch $@

$(KEY_DIR)/serial: | $(KEY_DIR)
	echo 01 > $@

$(KEY_DIR):
	mkdir $@
