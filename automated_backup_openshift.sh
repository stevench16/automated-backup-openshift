#!/bin/bash

# Configuración
#NODES=("contenedores-rt8zs-master-0" "contenedores-rt8zs-master-1" "contenedores-rt8zs-master-2")
NODES=("contenedores-rt8zs-master-0")
BACKUP_DIR="/home/core/assets/backup"
DATE=$(date +"%Y-%m-%d_%H%M")
LOG_FILE="/var/log/backup_files.log"  # Archivo para registrar nombres generado

# Configuración de Azure File Share
AZURE_STORAGE_ACCOUNT="cnt4lro"               # Nombre de la cuenta de almacenamiento
AZURE_FILE_SHARE="backup-openshift-etcd"      # Nombre del File Share
AZURE_STORAGE_KEY="PMcBMTXc79dPKuTuZwlEjnq2+jJ5FIBQMUGjYhWDmRv7dUSNqerLESQRGmvdQJ5+9+AbGbRS+qtCZYb3zFLhHg=="      # Clave de acceso de la cuenta
MOUNT_POINT="/mnt/backup-openshift-etcd"      # Punto de montaje local para el File Share

#Configuración OpenShift Container Platform

OC_SERVER="https://api.contenedores.nube-mintic.gov.co:6443"
OC_TOKEN=$(cat /opt/scripts/oc_token)


# Función para realizar backup en un nodo
backup_node() {

    # Configurar el token como autenticación
    oc login --token=$OC_TOKEN --server=$OC_SERVER
    if [ $? -ne 0 ]; then
        echo "Error: No se pudo autenticar en OpenShift con el token."
        exit 1
    fi
    
    echo "Successfully:Autenticación correcta Openshift."

    local NODE=$1
    echo "Iniciando sesión debug en el nodo: $NODE"

    # Iniciar sesión en modo debug como root para realizar el backup
    oc debug --as-root node/$NODE -- bash -c "
        echo 'Entrando al modo debug en $NODE para realizar el backup...'

        # Cambiar al directorio /host
        chroot /host bash -c '
            echo \"Cambiando a /host...\"

            # Crear el directorio de backups si no existe
            mkdir -p $BACKUP_DIR

            # Ejecutar el script de backup
            echo \"Ejecutando el script cluster-backup.sh...\"
            /usr/local/bin/cluster-backup.sh $BACKUP_DIR

            # Verificar si los archivos se generaron correctamente

            echo \"La variable DATE contiene: $DATE\"

            SNAPSHOT_FILE=\$(ls $BACKUP_DIR | grep \"^snapshot_${DATE}\")
            STATIC_FILE=\$(ls $BACKUP_DIR | grep \"^static_kuberesources_${DATE}\")
            if [ -n \"\$SNAPSHOT_FILE\" ] && [ -n \"\$STATIC_FILE\" ]; then
                echo \"Backup realizado correctamente en $NODE.\"
            else
                echo \"Error al realizar el backup en $NODE.\"
                exit 1
            fi


            # Detectar los archivos generados
            echo \"Detectando los archivos generados...\"

            if [ -n \"\$SNAPSHOT_FILE\" ] && [ -n \"\$STATIC_FILE\" ]; then
                echo \"Archivos generados correctamente:\"
                echo \"Snapshot: \$SNAPSHOT_FILE\"
                echo \"Static Kubernetes Resources: \$STATIC_FILE\"
            else
                echo \"Error al detectar los archivos generados en $BACKUP_DIR.\"
                exit 1
            fi
            #------------------------------------------------------------------------------------------------------------------------------------ 
            # Asegurarse de que el directorio de montaje exista
            echo \"Crear el nuevo directorio $MOUNT_POINT .........\"
            mkdir -p $MOUNT_POINT

            test -d /mnt/backup-openshift-etcd && echo \"Successfully:El punto de montaje se creó correctamente......\" || echo \"Error:El punto de montaje no se creó.......\"

            # Intentar montar el Azure File Share
            echo \"Montando el Azure File Share $AZURE_FILE_SHARE..............\"
            mount -t cifs //$AZURE_STORAGE_ACCOUNT.file.core.windows.net/$AZURE_FILE_SHARE $MOUNT_POINT \
            -o vers=3.0,username=$AZURE_STORAGE_ACCOUNT,password=$AZURE_STORAGE_KEY,dir_mode=0777,file_mode=0777

            # Verificar si el montaje fue exitoso
            if [ $? -ne 0 ]; then
                echo \"Error: No se pudo montar el Azure File Share $AZURE_FILE_SHARE en $MOUNT_POINT.....\"
                echo \"Por favor, verifica que el File Share existe y que las credenciales son correctas.....\"
                # exit 1
            fi
            echo \"Successfully:Azure File Share montado correctamente en $MOUNT_POINT.\"
            
            #------------------------------------------------------------------------------------------------------------------------------------

 
            # Mover los archivos generados al Azure File Share
            echo \"Moviendo archivos al Azure File Share...\"
            mv $BACKUP_DIR/\$SNAPSHOT_FILE $MOUNT_POINT/
            mv $BACKUP_DIR/\$STATIC_FILE $MOUNT_POINT/

            # Verificar si los archivos se movieron correctamente
            if [ -f $MOUNT_POINT/\$SNAPSHOT_FILE ] && [ -f $MOUNT_POINT/\$STATIC_FILE ]; then
                echo \"Archivos movidos correctamente al Azure File Share.\"
            else
                echo \"Error al mover los archivos al Azure File Share.\"
               # exit 1
            fi
            
            # Registrar los nombres en un log local
            echo \"Registrando nombres en el log local...\"
            echo \"$(date +"%Y-%m-%d %H:%M:%S") - Archivos respaldados: \$SNAPSHOT_FILE, \$STATIC_FILE\" >> $LOG_FILE

            # Eliminar los archivos locales
            echo \"Eliminando archivos locales en $BACKUP_DIR...\"
           rm -f $BACKUP_DIR/\$SNAPSHOT_FILE $BACKUP_DIR/\$STATIC_FILE
            
            # Desmontar el Azure File Share
           umount $MOUNT_POINT
            if [ $? -eq 0 ]; then
                echo \"Successfully:Azure File Share desmontado correctamente.\"
            else
                echo \"Advertencia: No se pudo desmontar el Azure File Share.\"
            fi

        '

        # Salir del modo chroot
        echo 'Saliendo del modo chroot...'
    "
    # Desmontar el Azure File Share
    #umount $MOUNT_POINT
    if [ $? -eq 0 ]; then
        echo "Azure File Share desmontado correctamente."
    else
        echo "Advertencia: No se pudo desmontar el Azure File Share."
    fi
}

# Ejecutar el backup en cada nodo
for NODE in "${NODES[@]}"; do
    backup_node $NODE
done

echo "Successfully:Proceso de backup Openshift completado."
