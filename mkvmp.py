import paramiko

server_list = [
    {'host': '23', 'ip': '10.1.75.23'},
    {'host': '24', 'ip': '10.1.75.24'},
    {'host': '25', 'ip': '10.1.75.25'},
    {'host': '26', 'ip': '10.1.75.26'},
    {'host': '27', 'ip': '10.1.75.27'},
    {'host': '28', 'ip': '10.1.75.28'},
    {'host': '29', 'ip': '10.1.75.29'},
    {'host': '30', 'ip': '10.1.75.30'},
    {'host': '31', 'ip': '10.1.75.31'},
    {'host': '32', 'ip': '10.1.75.32'}
]

json_content = '''{
  "apiVersion": "doslab.io/v1",
  "kind": "VirtualMachinePool",
  "metadata": {
    "name": "cephfspool%s",
    "labels": {
      "host": "%s"
    }
  },
  "spec": {
    "nodeName": "%s",
    "lifecycle": {
      "createPool": {
        "type": "cephfs",
        "url": "/var/lib/libvirt/myfs",
        "content": "vmdi",
        "auto-start": true,
        "source-host": "10.254.252.249:6789",
        "source-path": "/volumes/data"
      }
    }
  }
}'''

directory_path = '/home/gratename/vms/'

for server in server_list:
    ssh = paramiko.SSHClient()
    ssh.load_system_host_keys()
    ssh.connect(server['ip'])
    sftp = ssh.open_sftp()
    
    file_path = directory_path + 'vmp.json'
    with ssh.open_sftp().file(file_path, 'w') as f:
        f.write(json_content % (server['host'], server['ip'], server['ip']))

    command = f'kubectl apply -f {file_path}'
    stdin, stdout, stderr = ssh.exec_command(command)
    print(stdout.read().decode())
    ssh.close()