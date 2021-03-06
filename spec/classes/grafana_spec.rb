require 'spec_helper'

describe 'grafana' do
  # get all supported OSes from metadata.json
  on_supported_os.each do |os, facts|

    # mock all facts
    # reproducible builds
    context "on #{os}" do
      let(:facts) do
        facts
      end

      # start with the basic tests
      context 'with default values' do
        it { is_expected.to compile }
        it { is_expected.to contain_anchor('grafana::begin') }
        it { is_expected.to contain_class('grafana') }
        it { is_expected.to contain_class('grafana::params') }
        it { is_expected.to contain_class('grafana::install') }
        it { is_expected.to contain_class('grafana::config') }
        it { is_expected.to contain_class('grafana::service') }
        it { is_expected.to contain_anchor('grafana::end') }
      end

      context 'with parameter install_method is set to package' do
        # check the operatingsystem
        case facts[:osfamily]
        # do all the debian specific stuff
        when 'Debian'
          download_location = '/tmp/grafana.deb'

          describe 'use wget to fetch the package to a temporary location' do
            it { is_expected.to contain_wget__fetch('grafana').with_destination(download_location) }
            it { is_expected.to contain_wget__fetch('grafana').that_comes_before('Package[grafana]') }
          end

          describe 'install dependencies first' do
            it { is_expected.to contain_package('libfontconfig1').with_ensure('present').that_comes_before('Package[grafana]') }
          end

          describe 'install the package' do
            it { is_expected.to contain_package('grafana').with_provider('dpkg') }
            it { is_expected.to contain_package('grafana').with_source(download_location) }
          end
          # do all the redhat stuff
        when 'RedHat'
          describe 'install dependencies first' do
            it { is_expected.to contain_package('fontconfig').with_ensure('present').that_comes_before('Package[grafana]') }
          end

          describe 'install the package' do
            it { is_expected.to contain_package('grafana').with_provider('rpm') }
          end
        end
      end

      context 'with parameter install_method is set to repo' do
        let(:params) do
          {
            install_method: 'repo'
          }
        end

        case facts[:osfamily]
        when 'Debian'
          describe 'install apt repo dependencies first' do
            it { is_expected.to contain_class('apt') }
            it { is_expected.to contain_apt__source('grafana').with(release: 'wheezy', repos: 'main', location: 'https://packagecloud.io/grafana/stable/debian') }
            it { is_expected.to contain_apt__source('grafana').that_comes_before('Package[grafana]') }
          end

          describe 'install dependencies first' do
            it { is_expected.to contain_package('libfontconfig1').with_ensure('present').that_comes_before('Package[grafana]') }
          end

          describe 'install the package' do
            it { is_expected.to contain_package('grafana').with_ensure('2.5.0') }
          end
        when 'RedHat'
          describe 'yum repo dependencies first' do
            it { is_expected.to contain_yumrepo('grafana').with(baseurl: 'https://packagecloud.io/grafana/stable/el/' + facts[:operatingsystemmajrelease] + '/$basearch', gpgkey: 'https://packagecloud.io/gpg.key https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana', enabled: 1) }
            it { is_expected.to contain_yumrepo('grafana').that_comes_before('Package[grafana]') }
          end

          describe 'install dependencies first' do
            it { is_expected.to contain_package('fontconfig').with_ensure('present').that_comes_before('Package[grafana]') }
          end

          describe 'install the package' do
            it { is_expected.to contain_package('grafana').with_ensure('2.5.0-1') }
          end
        end
      end

      context 'with parameter install_method is set to repo and manage_package_repo is set to false' do
        let(:params) do
          {
            install_method: 'repo',
            manage_package_repo: false,
            version: 'present'
          }
        end

        case facts[:osfamily]
        when 'Debian'
          describe 'install dependencies first' do
            it { is_expected.to contain_package('libfontconfig1').with_ensure('present').that_comes_before('Package[grafana]') }
          end

          describe 'install the package' do
            it { is_expected.to contain_package('grafana').with_ensure('present') }
          end
        when 'RedHat'
          describe 'install dependencies first' do
            it { is_expected.to contain_package('fontconfig').with_ensure('present').that_comes_before('Package[grafana]') }
          end

          describe 'install the package' do
            it { is_expected.to contain_package('grafana').with_ensure('present') }
          end
        end
      end

      context 'with parameter install_method is set to archive' do
        let(:params) do
          {
            install_method: 'archive'
          }
        end

        install_dir    = '/usr/share/grafana'
        service_config = '/usr/share/grafana/conf/custom.ini'
        archive_source = 'https://grafanarel.s3.amazonaws.com/builds/grafana-2.5.0.linux-x64.tar.gz'

        describe 'extract archive to install_dir' do
          it { is_expected.to contain_archive('/tmp/grafana.tar.gz').with_ensure('present') }
          it { is_expected.to contain_archive('/tmp/grafana.tar.gz').with_source(archive_source) }
          it { is_expected.to contain_archive('/tmp/grafana.tar.gz').with_extract_path(install_dir) }
        end

        describe 'create grafana user' do
          it { is_expected.to contain_user('grafana').with_ensure('present').with_home(install_dir) }
          it { is_expected.to contain_user('grafana').that_comes_before('File[/usr/share/grafana]') }
        end

        describe 'manage install_dir' do
          it { is_expected.to contain_file(install_dir).with_ensure('directory') }
          it { is_expected.to contain_file(install_dir).with_group('grafana').with_owner('grafana') }
        end

        describe 'configure grafana' do
          it { is_expected.to contain_file(service_config).with_ensure('file') }
        end

        describe 'run grafana as service' do
          it { is_expected.to contain_service('grafana-server').with_ensure('running').with_provider('base') }
          it { is_expected.to contain_service('grafana-server').with_hasrestart(false).with_hasstatus(false) }
        end

        context 'when user already defined' do
          let(:pre_condition) do
            'user{"grafana":
              ensure => present,
            }'
          end
          describe 'do NOT create grafana user' do
            it { is_expected.not_to contain_user('grafana').with_ensure('present').with_home(install_dir) }
          end
        end

        context 'when service already defined' do
          let(:pre_condition) do
            'service{"grafana-server":
              ensure     => running,
              hasrestart => true,
              hasstatus  => true,
            }'
          end
          # let(:params) {{ :service_name => 'grafana-server'}}
          describe 'do NOT run service' do
            it { is_expected.not_to contain_service('grafana-server').with_hasrestart(false).with_hasstatus(false) }
          end
        end
      end

      context 'invalid parameters' do
        context 'cfg' do
          describe 'should raise an error when cfg parameter is not a hash' do
            let(:params) do
              {
                cfg: []
              }
            end

            it { expect { is_expected.to contain_package('grafana') }.to raise_error(Puppet::Error, %r{cfg parameter must be a hash}) }
          end

          describe 'should not raise an error when cfg parameter is a hash' do
            let(:params) do
              {
                cfg: {}
              }
            end

            it { is_expected.to contain_package('grafana') }
          end
        end
      end

      context 'configuration file' do
        describe 'should not contain any configuration when cfg param is empty' do
          it { is_expected.to contain_file('/etc/grafana/grafana.ini').with_content("# This file is managed by Puppet, any changes will be overwritten\n\n") }
        end

        describe 'should correctly transform cfg param entries to Grafana configuration' do
          let(:params) do
            {
              cfg: {
                'app_mode' => 'production',
                'section'  => {
                  'string'  => 'production',
                  'number'  => 8080,
                  'boolean' => false,
                  'empty'   => ''
                }
              },
              ldap_cfg: {
                'servers' => [
                  { 'host' => 'server1',
                    'use_ssl'         => true,
                    'search_filter'   => '(sAMAccountName=%s)',
                    'search_base_dns' => ['dc=domain1,dc=com'] },
                  { 'host' => 'server2',
                    'use_ssl'         => true,
                    'search_filter'   => '(sAMAccountName=%s)',
                    'search_base_dns' => ['dc=domain2,dc=com'] }
                ],
                'servers.attributes' => {
                  'name'      => 'givenName',
                  'surname'   => 'sn',
                  'username'  => 'sAMAccountName',
                  'member_of' => 'memberOf',
                  'email'     => 'email'
                }
              }
            }
          end

          expected = "# This file is managed by Puppet, any changes will be overwritten\n\n"\
                     "app_mode = production\n\n"\
                     "[section]\n"\
                     "boolean = false\n"\
                     "empty = \n"\
                     "number = 8080\n"\
                     "string = production\n"

          it { is_expected.to contain_file('/etc/grafana/grafana.ini').with_content(expected) }

          ldap_expected = "\n[[servers]]\n"\
                           "host = \"server1\"\n"\
                           "search_base_dns = [\"dc=domain1,dc=com\"]\n"\
                           "search_filter = \"(sAMAccountName=%s)\"\n"\
                           "use_ssl = true\n"\
                           "\n"\
                          "[[servers]]\n"\
                           "host = \"server2\"\n"\
                           "search_base_dns = [\"dc=domain2,dc=com\"]\n"\
                           "search_filter = \"(sAMAccountName=%s)\"\n"\
                           "use_ssl = true\n"\
                           "\n"\
                           "[servers.attributes]\n"\
                           "email = \"email\"\n"\
                           "member_of = \"memberOf\"\n"\
                           "name = \"givenName\"\n"\
                           "surname = \"sn\"\n"\
                           "username = \"sAMAccountName\"\n"\
                           "\n"

          it { is_expected.to contain_file('/etc/grafana/ldap.toml').with_content(ldap_expected) }
        end
      end
    end
  end
end
