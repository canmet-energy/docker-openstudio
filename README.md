# OpenStudio

Container for OpenStudio along with Ruby, Bundler, build-essential and various development libraries.

## Example

Run the following command in the directory of the script to run

```
docker run -it --rm nrel/openstudio bundle && ruby <name-of-script.rb>
<or>
docker run -it --rm nrel/openstudio bundle && rake <name-of-task>
```

# Create Image outside of the NRCan Network:

Use the existing Dockerfile and type the following (assuming you are building the 3.11.0 version):

```
docker build -t canmet/docker-openstudio:3.11.0 .
```

# Create Image within the NRCan Network:

Get a copy of the NRCan certificate (if it is in another format convert it to .pem) and put it in the root directory of your version of this repository.  Rename the certificate to be 'cacert.pem'.  Then type the following in the command line:

```
docker build -t canmet/docker-openstudio:3.11.0 . --build-arg LOCAL_NRCAN=true
```
