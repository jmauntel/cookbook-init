#!/bin/bash

NORMAL='\033[0m'
RED='\033[1;31m'
GREEN='\033[1;32m'

cookbookName=${1}
rubyVersion="ruby-1.9.3-p392"

[[ -z $cookbookName ]] && {
  printf "\n%s\n\n" "Cookbook name not passed to cookbook-init"
  exit 1
}

printMsg () {
  printf "\n${GREEN}%s\n${NORMAL}" "$@"
}

die () { 
  printf "\n${RED}%s\n\n${NORMAL}" "$@"
  exit 1
}

printMsg "--- Creating $cookbookName cookbook via Berkshelf ---"
berks cookbook $cookbookName --chef-minitest || die "Failed to create $cookbookName cookbook via Berkshelf"

printMsg "--- Switching to $cookbookName directory ---"
cd $cookbookName || die "Failed to switch to $cookbookName directory"

printMsg "--- Configuring ruby version and gemset ---"
echo $rubyVersion > .ruby-version
echo $cookbookName > .ruby-gemset
cd .. && cd $cookbookName

printMsg "--- Using ruby version \"$(ruby --version | awk '{print $2}')\" ---"
printMsg "--- Using gemset \"$(rvm gemset name)\" ---"

printMsg "--- Updating Gemfile ---"
cat > Gemfile <<EOF
source 'https://rubygems.org'

gem 'berkshelf', '< 3.0.0'
gem 'foodcritic', '~> 3.0.0'
gem 'kitchen-vagrant'
EOF

printMsg "--- Install required gems ---"
bundle install || die "Failed to install required gems"

printMsg "--- Initialize test-kitchen ---"
[[ ! -f .kitchen.yml ]] && {
  kitchen init || die "Failed to initialize test-kitchen"
}

printMsg "--- Reconfigure .kitchen.yml ---"
cat > .kitchen.yml <<EOF

---
driver_plugin: vagrant
platforms:
- name: centos-6.3
  driver_config:
    box: opscode-centos-6.3
    box_url: https://opscode-vm.s3.amazonaws.com/vagrant/boxes/opscode-centos-6.3.box
    customize:
      memory: 1024
- name: centos-5.8
  driver_config:
    box: opscode-centos-5.8
    box_url: https://opscode-vm.s3.amazonaws.com/vagrant/boxes/opscode-centos-5.8.box
    customize:
      memory: 1024
suites:
- name: default
  run_list:
  - "recipe[test-kitchen-example]"
  attributes: {}

suites:
- name: default
  run_list: [
    "recipe[minitest-handler::default]",
    "recipe[${cookbookName}::default]"
  ]
  attributes: {}
EOF

printMsg "--- Initialize local git repo and perform initial commit ---"
git init || die "Failed to initialize local git repo"
git add . || die "Failed to add files to local repo"
git commit -a -m "Initial commit" || die "Failed to commit changes to local repo"

printMsg "--- Create README.md template ---"
cat > README.md <<EOF
##Jenkins Status
[![Build Status](https://jenkins.acme.com/jenkins/buildStatus/icon?job=${cookbookName})](https://jenkins.acme.com/jenkins/job/${cookbookName}/)

## Description

INSERT DESCRIPTION FOR $cookbookName HERE

---

## Supported Platforms

The following platforms and versions are tested and supported using
Opscode's [test-kitchen](http://github.com/opscode/test-kitchen).
 
* CentOS 5.8, 6.3

The following platform families are supported in the code, and are
assumed to work based on the successful testing on CentOS.

* RedHat 5.8, 6.3

---

## Cookbook Dependencies

* None 

---

## Attributes

* None

---

## Recipes

* default
    + None

---

## Tests

* default
    + None

---

## Author

Author: First Last (flast@acme.com)
EOF

printMsg "--- Updating Copyright in default recipe ---"
sed -i -e 's/YOUR_NAME/Acme, Inc./g' recipes/default.rb || die "Failed to update copyright data in default recipe"

printMsg "--- Cookbook development environment for $cookbookName initialized ---"
