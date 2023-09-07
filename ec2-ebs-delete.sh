#!/bin/bash

# Arreglo con los IDs de las instancias EC2
instance_ids=("i-023e454ff10b11d03")

# Iterar sobre cada ID de instancia
for instance_id in "${instance_ids[@]}"; do
    # Verificar que la instancia esté detenida
    echo ""
    echo "Verificando el estado de la instancia $instance_id..."
    instance_status=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].State.Name' --output text)

     if [ "$instance_status" != "stopped" ]; then
        read -p "La instancia $instance_id no está detenida. ¿Deseas detenerla antes de continuar? (y/n): " user_input
        if [ "$user_input" == "y" ]; then
            # Detener la instancia
            aws ec2 stop-instances --instance-ids "$instance_id"
            echo "Deteniendo instancia $instance_id..."
            # Espera hasta que la instancia esté completamente detenida
            aws ec2 wait instance-stopped --instance-ids "$instance_id"
            echo "La instancia $instance_id ha sido detenida."
        else
            echo "Continuar proceso con la siguiente instancia..."
            continue
        fi
    fi

    # Obtener IDs de volúmenes EBS adjuntos
    echo "Obteniendo IDs de volúmenes EBS asociados..."
    volume_ids=($(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId' --output text))

    # Obtener los nombres de dispositivo de los volúmenes EBS adjuntos
    device_names=($(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].DeviceName' --output text))

    # Crear un diccionario que mapee los nombres de dispositivo a los IDs de volumen
    declare -A device_to_volume
    for i in "${!device_names[@]}"; do
        device_to_volume["${device_names[$i]}"]="${volume_ids[$i]}"
    done

    # Identificar los volúmenes con protección contra borrado (Delete On Termination)
    protected_device_names=()
    for device_name in "${!device_to_volume[@]}"; do
        volume_id="${device_to_volume["$device_name"]}"
        delete_on_termination=$(aws ec2 describe-volumes --volume-ids "$volume_id" --query 'Volumes[0].Attachments[0].DeleteOnTermination' --output text)
        if [ "$delete_on_termination" == "False" ]; then
            protected_device_names+=("$device_name")
        fi
    done

    # Listar los volúmenes con protección contra borrado
    if [ ${#protected_device_names[@]} -gt 0 ]; then
        echo "Los siguientes dispositivos tienen protección contra borrado (Delete On Termination):"
        for device_name in "${protected_device_names[@]}"; do
            echo "- ${device_to_volume["$device_name"]}"
        done

        # Preguntar si el usuario quiere desactivar la protección en estos dispositivos
        read -p "¿Desea desactivar la protección en estos dispositivos? (y/n): " response
        if [ "$response" == "y" ]; then
            for device_name in "${protected_device_names[@]}"; do
                volume_id="${device_to_volume["$device_name"]}"
                # Usar minúsculas "false" y formatear como JSON válido
                mapping='[{"DeviceName":"'${device_name}'","Ebs":{"VolumeId":"'${volume_id}'","DeleteOnTermination":true}}]'
                aws ec2 modify-instance-attribute --instance-id "$instance_id" --block-device-mappings "$mapping"
            done
        fi
    else
        echo "No se encontraron dispositivos con protección contra borrado en la instancia $instance_id."
    fi

    # Preguntar si se debe proceder con eliminar la instancia
    read -p "¿Desea proceder con la eliminación de la instancia $instance_id? (y/n): " response
    if [ "$response" == "y" ]; then
        aws ec2 terminate-instances --instance-ids "$instance_id"
    fi
done
