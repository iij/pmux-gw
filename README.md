## Pmux::Gateway

   Pmux gateway is an executor for Pmux (https://github.com/iij/pmux) through HTTP request.

## Requirements

  * ruby 1.8.7, 1.9.1 or higher
  * pmux 
  * gflocator 
  * eventmachine 
  * em_pessimistic
  * eventmacnine/evma_httpserver https://github.com/eventmachine/evma_httpserver.git 

## Installation

### Install dependency programs
  
  gem install gflocator  
  gem install pmux  
  gem install eventmachine  
  gem install em_pessimistic  
  git clone https://github.com/eventmachine/evma_httpserver.git  
  cd evma_httpserver  
  rake gem:build  
  gem install eventmachine_httpserver-0.2.1.gem  
  (I do not recommend "gem install eventmachine_httpserver")  
  
### Install pmux-gw

  gem install pmux-gw  

## Usage

  pmux-gw [-c config] [-F] [-h]  
  -c : specified config file  
  -F : foreground mode  
  -h : print usage  

## Quick start

### Install glusterfs client (http://www.gluster.org/)

#### CentOS/RHEL

  rpm -ivh glusterfs-3.3.1-1.el6.x86_64.rpm  
  rpm -ivh glusterfs-fuse-3.3.1-1.el6.x86_64.rpm  

### Create an environment that can use pmux

  mkdir /mnt/volume  
  mount -t glusterfs gfsnode1:volume /mnt/volume  
  gflocator  
  useradd -m admin  
  sudo -u admin ssh-keygen  
  (copy publickey to glusterfs nodes)  

### Make sure that the following command will work  

  sudo -u admin pmux --status -h 127.0.0.1  
  sudo -u admin pmux --mapper="ls -al" --storage=glusterfs --locator-host=127.0.0.1  /mnt/volume  
 
### Create an environment that can use pmux-gw

  mkdir /etc/pmux-gw  
  cp <pmux-geteway-install-path>/conf/pmux-gw.conf /etc/pmux-gw/pmux-gw.conf  
  cp <pmux-geteway-install-path>/conf/password /etc/pmux-gw/password  
  chown -R admin:admin /etc/pmux-gw/password  
  chmod -R 600 /etc/pmux-gw/password  
  pmux-gw  
  curl --basic -u user:pass -iv  'http://127.0.0.1:18080/pmux?mapper=ls&file=/'  

## Resource URL

### http://<server_name>:18080/pmux

  Resource to execute the Pmux

#### method

  * GET
  * POST

#### parameters 

  * mapper
    * Specified as a string to exected mapper command.
    * Must be placed on the glusterfs mapper program
    * Be distributed to each glusterfs nodes using ship-file is possible mapper program on glusterfs
  * file  
    * Specifies the file to be processed
    * This parameter can be specified multiple
    * Can also be used with file-glob
    * The default program is not distributed reducer
    * Specifies the path on the volume that was mounted
  * file-glob
    * Specified in the expression pattern of the shell files to be processed
    * Specification of the pattern, according to the specifications of the pattern glob (3)
    * This parameter can be specified multiple
    * Can also be used with file-glob
    * The default program is not distributed reducer
    * Specifies the path on the volume that was mounted
  * ship-file
    * Specifies the path of the file to be distributed to each node of the pmux
    * You use this if you want to distribute to each node in the mapper program on the glusterfs pmux
    * Can be distributed more files than mapper script (configuration files, for example)
    * This parameter can be specified multiple
    * Specifies the path on the volume that was mounted
  * reducer
    * specified as a string to be executed reducer command
    * Reducer is not used the program default
  * num-r
    * Reducer to run the program number.
    * Default 0 is used
  * ff
    * Number of tasks if you want to be lumped fine fusion task
    * I do not fusion when omitted
  * storage
    * Specify the type of storage you want to use
    * Default is "glusterfs"
  * locator-host
    * Specifies the hostname or address of the locator to return the position of the entity in the file
    * default is "127.0.0.1"
  * locator-port
    * Specifies the port number of the locator that returns the position of the entity in the file
    * Default is automatically set according to the type of storage
  * detect-error 
    * Specifies the on / off
    * if on, Return a response waiting for the completion of the execution of pmux, it checks whether an error occurred. 
    * The default is off

### http://<server_name>:18080/history

  Resources of the request to refer to the history

### http://<server_name>:18080/existence

  Resources to monitor the presence of process
     
## Package createting

  * create gem
  $ make

  * install
  # make install
    or 
  # gem install pkg//pmux-gw-*.gem

  * create rpm
  $ make rpmbuild

  * install rpm
  $ rpm -ivh rpm/RPMS/noarch/rubygems-pmux-gw-*.noarch.rpm

## Links
 * Glusterfs
   * http://www.gluster.org/
 * Gflocator
   * https://github.com/iij/gflocator
 * Pmux
   * https://github.com/iij/pmux
