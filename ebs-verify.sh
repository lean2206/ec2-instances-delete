#!/bin/bash

# Arreglo con los IDs de los volúmenes EBS a verificar
volume_ids=("vol-0a6d9c8c78510d75d" "vol-045dee35f25a9b05c")


# Iterar sobre cada ID de volumen
for volume_id in "${volume_ids[@]}"; do
    # Utilizar describe-volumes para verificar si el volumen existe
    result=$(aws ec2 describe-volumes --volume-ids "$volume_id" 2>&1)
    if [ $? -eq 0 ]; then
        echo "El volumen con ID $volume_id existe en tu cuenta de AWS."
    else
        echo "El volumen con ID $volume_id no existe en tu cuenta de AWS o hubo un error al verificarlo."
    fi
done

