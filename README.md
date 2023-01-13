# OpenStudio

Container for OpenStudio along with Ruby 2.0, Bundler, build-essentials and various development libraries for gem support.

## Example

Run the following command in the directory of the script to run

```
docker run -it --rm nrel/openstudio bundle && ruby <name-of-script.rb>
<or>
docker run -it --rm nrel/openstudio bundle && rake <name-of-task>
```

# NRCan Instructions

Note that there are now two Dockerfiles:  Dockerfile and Dockerfile_nrcan.  This was done because of nrcan security restrictions.  Please follow the instructions below to create a Docker image based on the Dockerfile:

# Create Image outside of the NRCan Network:

Use the existing Dockerfile and type the following (assuming you are building the 3.5.1 version):

```
docker build -t canmet/docker-openstudio:3.5.1 .
```

# Create Image within the NRCan Network:

Get a copy of the NRCan certificate (if it is in another format convert it to .pem) and put it in the root directory of your version of this repository.  Rename the certificate to be 'cacert.pem'.  Then type the following in the command line:

```
docker build -f Dockerfile_nrcan -t canmet/docker-openstudio:3.5.1 .
```
