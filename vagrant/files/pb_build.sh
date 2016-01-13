cd /vagrant/api
find /vagrant/api/lib  -type f -exec echo '--changed={}' \; | xargs dart /vagrant/api/build.dart --local
cd - > /dev/null
