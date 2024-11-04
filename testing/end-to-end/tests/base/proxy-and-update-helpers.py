class UpdateServer:
    def __init__(self, vm, product_name, http_root):
        self.vm = vm
        self.product_name = product_name
        self.http_root = http_root

    def wait_for_unit(self):
        self.vm.wait_for_unit('static-web-server.service')

    def set_latest_version(self, version):
        self.vm.succeed(f"echo -n '{version}' > {self.http_root}/latest")

    def bundle_filename(self, version):
        return f"{self.product_name}-{version}.raucb"

    def bundle_path(self, version):
        bundle = self.bundle_filename(version)
        return f"{self.http_root}/{version}/{bundle}"

    def add_bundle(self, version, filepath=None):
        path = self.bundle_path(version)
        self.vm.succeed(f"mkdir -p {self.http_root}/{version}")
        if filepath:
            self.vm.succeed(f"ln -s {filepath} {path}")
        else:
            self.vm.succeed(f"echo -n 'FAKE_BUNDLE' > {path}")
