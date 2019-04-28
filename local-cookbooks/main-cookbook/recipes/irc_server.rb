instance = ::ChefCookbook::Instance::Helper.new(node)
secret = ::ChefCookbook::Secret::Helper.new(node)

apt_update 'default' do
  action :update
  notifies :install, 'build_essential[default]', :immediately
end

build_essential 'default' do
  action :nothing
end

locale 'en' do
  lang 'en_US.utf8'
  lc_all 'en_US.utf8'
  action :update
end

include_recipe 'ntp::default'

fail2ban_enabled = node.fetch('fail2ban', {}).fetch('enabled', false)

if fail2ban_enabled
  node.default['firewall']['iptables']['defaults'][:ruleset] = {
    '*filter' => 1,
    ':INPUT DROP' => 2,
    ':FORWARD ACCEPT' => 3,
    ':OUTPUT ACCEPT_FILTER' => 4,
    '-N fail2ban' => 45,
    '-A fail2ban -j RETURN' => 45,
    '-A INPUT -j fail2ban' => 45,
    'COMMIT_FILTER' => 100
  }
end

include_recipe 'firewall::default'

if fail2ban_enabled
  package 'fail2ban' do
    action :install
  end

  service 'fail2ban' do
    action [:enable, :start]
    subscribes :restart, 'firewall[default]', :delayed
  end

  template '/etc/fail2ban/jail.local' do
    source 'fail2ban/jail.local.erb'
    owner instance.root
    group node['root_group']
    mode 0644
    variables(
      chain: 'fail2ban',
      action: 'action_mwl',
      destemail: node['fail2ban']['destemail'],
      sender: node['fail2ban']['sender'],
      sendername: node['fail2ban']['sendername']
    )
    action :create
    notifies :restart, 'service[fail2ban]', :delayed
  end
end

ssmtp 'default' do
  sender_email node['ssmtp']['sender_email']
  smtp_host node['ssmtp']['smtp_host']
  smtp_port node['ssmtp']['smtp_port']
  smtp_username node['ssmtp']['smtp_username']
  smtp_password secret.get("smtp:password:#{node['ssmtp']['smtp_username']}")
  smtp_enable_starttls node['ssmtp']['smtp_enable_starttls']
  smtp_enable_ssl node['ssmtp']['smtp_enable_ssl']
  from_line_override node['ssmtp']['from_line_override']
  action :install
end

firewall_rule 'irc' do
  port 6667
  source '0.0.0.0/0'
  protocol :tcp
  command :allow
end

firewall_rule 'irc_secure' do
  port 6697
  source '0.0.0.0/0'
  protocol :tcp
  command :allow
end
