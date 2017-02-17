Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-16.04"

  config.vm.network "private_network", ip: "192.168.50.4"

  config.ssh.insert_key = false

  config.vm.provision "shell" do |s|
    s.inline = "apt -y update && apt install -y python-minimal"  # Needed because 16.04 uses Python 3 as default
  end
end
