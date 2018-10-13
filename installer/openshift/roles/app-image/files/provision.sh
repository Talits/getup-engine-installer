#!/bin/bash

systemctl start docker || true
sleep 3
docker rm -f getup-engine|| true

state_dir=/state

# setup ssh for user centos
if [ ! -d ~centos/.ssh ]; then
    mkdir --mode=700 ~centos/.ssh
fi

chown -R centos.centos ~centos/.ssh

echo Generating ssh config
export SSH_CONFIG_FILE=~centos/.ssh/config

if [ ! -e ~centos/.ssh/config ]; then
    cat > ~centos/.ssh/config <<EOF
    Host github.com
        StrictHostKeyChecking   no
EOF
fi

echo Installing ssh keys
cp -f ${state_dir}/id_rsa ~centos/.ssh/
export ID_RSA_FILE=~centos/.ssh/id_rsa
export ID_RSA_PUB_FILE=${ID_RSA_FILE}.pub

if [ ! -e  "${ID_RSA_FILE}" ]; then
    echo -e "${ID_RSA}" > ${ID_RSA_FILE}
fi
chmod 0600 ${ID_RSA_FILE}

ssh-keygen -yf ${ID_RSA_FILE} > ${ID_RSA_PUB_FILE}
export ID_RSA_PUB="$(<${ID_RSA_PUB_FILE})"

chmod 0600 ${ID_RSA_PUB_FILE}

# Dwnload getup-engine
rm -rf /tmp/getup-engine
su - centos -c "git clone git@github.com:getupcloud/getup-engine.git /tmp/getup-engine"
cd /tmp/getup-engine

# Build docker container
./build

chcon -R -t svirt_sandbox_file_t ${state_dir}
docker run -it --rm \
    -v ${state_dir}/:/state \
    --env-file ${state_dir}/getupengine.env \
    -e "ID_RSA=$(<${state_dir}/id_rsa)" \
    -u root \
    --name getup-engine \
    getup-engine:latest /getup-engine/join-cluster

echo Cleanup...

# rm -rf ${state_dir}
# sudo docker rm -f getup-engine
# rm -f ${ID_RSA_FILE} ${ID_RSA_PUB_FILE}
