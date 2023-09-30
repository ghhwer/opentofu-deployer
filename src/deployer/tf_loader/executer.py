import os
from .aws_loader import StateFileLoaderS3

def execute_opentofu(env_opts):
    # Assuming you have the OpenTofu command available in the system path
    # Modify these commands as per your requirement
    var_file = env_opts['TOFU_VARS_FILE']
    chdir = env_opts['TOFU_CHDIR']
    init_command = f'opentofu -chdir={chdir} init'
    plan_command = f'opentofu -chdir={chdir} plan -var-file="{var_file}"'
    apply_command = f'opentofu -chdir={chdir} apply -var-file="{var_file}" -auto-approve'

    # Initialize OpenTofu
    exit_code = os.system(init_command)
    if exit_code != 0:
        raise RuntimeError('OpenTofu initialization failed.')

    # Generate OpenTofu plan
    exit_code = os.system(plan_command)
    if exit_code != 0:
        raise RuntimeError('OpenTofu plan generation failed.')

    if(env_opts.get('SKIP_APPLY', False) == False):
        # Execute OpenTofu apply
        exit_code = os.system(apply_command)
        if exit_code == 0:
            print('OpenTofu steps executed successfully.')
        else:
            raise RuntimeError('OpenTofu execution failed.')
    else:
        print('OpenTofu apply skipped...')

class TfLoader():
    def __init__(self, options, credentials):
        # Options
        self.options = options
        self.credentials = credentials
        
        # Options parse
        tofu_vars_path = self.options.get('TOFU_VARS_FILE', '/opt/deployer/vars.tfvars')
        tofu_ch_dir = self.options.get('TOFU_CHDIR', '/opt/deployer/infra')
        self.options['TOFU_VARS_FILE'] = tofu_vars_path
        self.options['TOFU_CHDIR'] = tofu_ch_dir

        self.state_file_loader = self.solve_state_file_loader()
    
    def run_opentofu(self,):
        print('Syncing with state file loader')
        self.state_file_loader.get_file()
        # Execute OpenTofu
        try:
            execute_opentofu(self.options)
        except RuntimeError as e:
            print('There was an error executing OpenTofu, syncing tf_state anyways...')
        self.state_file_loader.put_file()

    def solve_state_file_loader(self):
        tf_state_loader = self.options.get('TF_STATE_LOADER')
        if tf_state_loader  == 'AWS_S3':
            return StateFileLoaderS3(self.options, self.credentials)
        else:
            raise ValueError(f'Error while parsing "TF_STATE_LOADER": {tf_state_loader} is not supported!')