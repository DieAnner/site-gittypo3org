#
# Cookbook Name:: site-reviewtypo3org
# Recipe:: worker
#
# Copyright 2013, TYPO3 Association
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

deploy_base = "/srv/mq-worker-gittypo3org"

package ["ruby", "bundler", "ruby-dev", "build-essential"]

# create shared config directory
[
  deploy_base,
  "#{deploy_base}/shared",
  "#{deploy_base}/shared/config",
].each do |dir|
  directory dir do
    owner "git"
    group "git"
  end
end

# handle amqp password
if Chef::Config[:solo]
  Chef::Log.warn "AMQP connection will be disabled as running inside of chef-solo!"
  amqp_pass = "fooo"
else
  Chef::Log.info "AMQP #{node['site-gittypo3org']['amqp']['server']} and #{node['site-gittypo3org']['amqp']['user']} !"

  # read AMQP password from chef-vault
  amqp_pass = chef_vault_password(node['site-gittypo3org']['amqp']['server'], node['site-gittypo3org']['amqp']['user'])

end


# create a proper amqp.yml
template "#{deploy_base}/shared/config/amqp.yml" do
  owner      "git"
  group      "git"
  variables({
    :data => {
      :user => node['site-gittypo3org']['amqp']['user'],
      :pass => amqp_pass,
      :host => node['site-gittypo3org']['amqp']['server'],
      :vhost => node['site-gittypo3org']['amqp']['vhost']
    }
  })
end

# deploy resource for mq-worker-gittypo3org
deploy_revision "mq-worker-gittypo3org" do
  #action  :force_deploy
  deploy_to      deploy_base
  repository     "https://github.com/TYPO3-infrastructure/mq-worker-gittypo3org"
  migrate        false
  user           "git"
  group          "git"
  symlink_before_migrate ({
    'config/amqp.yml' => 'config/amqp.yml'
  })
  before_symlink do

    directory "#{deploy_base}/shared/log" do
      owner "git"
      group "git"
    end

    execute "bundle install --path=vendor/bundle --without development test" do
      cwd release_path
      user           "git"
    end

  end
  notifies :restart, "runit_service[mq-worker-gittypo3org]"
end


include_recipe "runit"

runit_service "mq-worker-gittypo3org" do
  owner          "git"
  group          "git"
  options ({
    :deploy_base => deploy_base}.merge(params)
  )
end
