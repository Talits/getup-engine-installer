#!/bin/bash

libDir=$(dirname ${0})

awsRegions=(
    ap-northeast-1
    ap-northeast-2
    ap-northeast-3
    ap-south-1
    ap-southeast-1
    ap-southeast-2
    ca-central-1
    cn-north-1
    cn-northwest-1
    eu-central-1
    eu-west-1
    eu-west-2
    eu-west-3
    sa-east-1
    us-east-1
    us-east-2
    us-gov-west-1
    us-west-1
    us-west-2
)

azureRegions=(
    australiaeast
    australiasoutheast
    brazilsouth
    canadacentral
    canadaeast
    centralindia
    centralus
    eastasia
    eastus
    eastus2
    francecentral
    francesouth
    japaneast
    japanwest
    koreacentral
    koreasouth
    northcentralus
    northeurope
    southcentralus
    southeastasia
    southindia
    uksouth
    ukwest
    westcentralus
    westeurope
    westindia
    westus
    westus2
)

gceRegions=(
    asia-east1
    asia-northeast1
    asia-south1
    asia-southeast1
    australia-southeast1
    europe-north1
    europe-west1
    europe-west2
    europe-west3
    europe-west4
    northamerica-northeast1
    southamerica-east1
    us-central1
    us-east1
    us-east4
    us-west1
    us-west2
)

provider_is()
{
    [ $PROVIDER == $1 ]
}

sel()
{
    local varName=${1}
    shift
    local options=( "$@" )
    local promptMesg=${varName//_/ }; promptMesg=${promptMesg,,}; promptMesg=${promptMesg^}
    local currentValue; eval "currentValue=\$$varName"

    if [ ${#options[@]} -eq 1 ]; then
        echo "Auto-selected value: $options"
        ex "$varName=${options}"
        return
    fi

    echo "----------------------------------------------"
    echo "---> Select" $(sed -e 's/^\s*\(.*\)\s*$/\1/' <<<$promptMesg)
    echo
    if [ -n "${currentValue}" ]; then
        local PS3="Type number to select [${currentValue}]: "
    else
        local PS3="Type number to select: "
    fi

    unset _value
    local _value
    select _value in "${options[@]}"; do
        break
    done

    ex "$varName=${_value}"
}

mult()
{
    local varName=${1}
    shift
    local options=( "$@" )
    local promptMesg=${varName//_/ }; promptMesg=${promptMesg,,}; promptMesg=${promptMesg^}
    local currentValue; eval "currentValue=\$$varName"

    echo "----------------------------------------------"
    echo "---> Type number to select" $(sed -e 's/^\s*\(.*\)\s*$/\1/' <<<$promptMesg)
    echo

    if [ -n "${currentValue}" ]; then
        local PS3="Space-separated list of numbers to select (* for all) [$currentValue]: "
    else
        local PS3="Space-separated list of numbers to select (* for all): "
    fi

    select _ in "${options[@]}"; do
        break
    done

    unset _value
    local _value
    if [ "$REPLY" == '*' ]; then
        _value="${options[*]}"
    else
        local i
        for i in ${REPLY}; do
            _value+="${options[$((i - 1))]} "
        done
    fi

    ex "$varName=${_value}"
}

rd()
{
    local varName=${1}
    local promptMesg=${varName//_/ }; promptMesg=${promptMesg,,}; promptMesg=${promptMesg^}
    local defaultValue=${2}
    local value=''

    if [ -v $varName ]; then
        eval "defaultValue=\$$varName"
    fi

    echo "----------------------------------------------"
    if [ -n "$defaultValue" ]; then
        read -p "--> $promptMesg [$defaultValue]: " value
        if [ -z "$value" ]; then
            value="$defaultValue"
        fi
    else
        read -p "--> $promptMesg: " value
    fi

    ex "$varName=$value"
}

ask()
{
    local promptMesg="${1}"
    if [ $# -eq 2 ]; then
        local defaultValue=${2}
    else
        local varName=${2}
        local defaultValue=${3}

        if [ -v $varName ]; then
            eval "defaultValue=\"\$$varName\""
        fi
    fi
    local value=''

    # normalize
    [ $defaultValue == true ] && defaultValue=y
    [ $defaultValue == false ] && defaultValue=n

    echo "----------------------------------------------"
    while [ "${value}" != y -a "${value}" != n ]; do
        read \
            -p "--> $promptMesg [$([ ${defaultValue:-_} == 'y' ] && echo Y || echo y )/$([ ${defaultValue:-_} == 'n' ] && echo N || echo n )]: "
            value="$REPLY"

        if [ -n "$defaultValue" -a -z "$value" ]; then
            value="$defaultValue"
        fi
        value=${value,,}
    done

    # normalize
    [ $value == y ] && value=true
    [ $value == n ] && value=false

    ex "# ${promptMesg} -> $value"
    if [ -v varName ]; then
        ex "$varName=$value"
    fi
    [ ${value} == true ]
}

pw()
{
    local varName=${1}
    local chars=${2:-128}

    if [ -v $varName ]; then
        eval "defaultValue=\"\$$varName\""
        ex "$varName=$defaultValue"
    else
        ex "$varName=$(openssl rand -hex $((chars / 2)) | tr -d '\n')"
    fi
}

_is_valid_var()
{
    if _should_store_var $1 && _should_export_var $1; then
        egrep -q "^$1(:|\s+|\$)" ${libDir}/configs.ini
    else
        return 0
    fi
}

_should_store_var()
{
    [ "${1::1}" != "_" ]
}

_should_export_var()
{
    [ "${1::1}" != "#" ]
}

ex()
{
    for varSpec; do
        local varName=${varSpec%%=*}
        local varValue="${varSpec#*=}"

        if _should_store_var ${varName}; then
            if _should_export_var "${varSpec}"; then
                echo "$varName=\"$varValue\"" >&3
            else
                echo "${varSpec}" >&3
            fi
        fi

        _should_export_var ${varName} && eval "export '$varSpec'"

        if ! _is_valid_var $varName; then
            echo "Undeclared config $varName=$varValue" >&2
            exit 1
        fi
    done
}

get_aws_key_pairs()
{
    echo -ne "\nReading SSH key pairs..." >&2
    aws ec2 describe-key-pairs \
        --query 'KeyPairs[*].KeyName' --output text || true
    echo >&2
}

list_aws_hosted_zones()
{
    echo -ne "\nReading Route53 hosted zones... " >&2
    aws route53 list-hosted-zones --query 'HostedZones[*].[Id, Name]' --output text | sed -e 's,/hostedzone/,,' -e 's/.$//'
    echo >&2
}

get_aws_hosted_zone_name()
{
    echo -ne "\nReading Route53 hosted zone $1... " >&2
    local zoneName=$(aws route53 get-hosted-zone \
        --id $1 --query 'HostedZone.Name' --output text || true)
    echo ${zoneName%%.}
    echo ${zoneName%%.} >&2
}

list_aws_availability_zones()
{
    local zone=$1
    echo -ne "\nReading availability zones for region $zone... " >&2
    aws ec2 describe-availability-zones --query 'AvailabilityZones[*].ZoneName' --output text
    echo >&2
}

list_gce_zones()
{
    local region=$1
    echo -ne "\nReading zones for region $region... " >&2
    gcloud compute zones list --filter="name=$1" --uri | sed -e 's,.*/,,'
    echo >&2
}
