
# ./install_sandreco.sh

source ../util/init.inc.sh
source ../util/reload_in_container.inc.sh

echo "$PWD"

# some problems since test files are in /usr/local, but we can't write to /usr/local
# since we are not root users. This will be solve because the .json will be written through 
# a separate script python
run ufwrun sandreco-experimental/tests/framework/900_fake_reco_test.json