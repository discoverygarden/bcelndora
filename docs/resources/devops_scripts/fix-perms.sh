#/bin/bash

helm_dir=/opt/helm_values

chgrp -R microk8s $helm_dir
chmod -R g+w $helm_dir
