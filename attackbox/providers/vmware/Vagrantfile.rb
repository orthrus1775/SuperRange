# Add Ubuntu server boxes
boxes.append(
  {
    :name => "{{lab_name}}-ubuntu-server-1",
    :ip => "{{ip_range}}.51",
    :box => "bento/ubuntu-24.04",
    :os => "linux",
    :cpus => 2,
    :mem => 4000,
    :forwarded_port => [
      {:guest => 22, :host => 2251, :id => "ssh"}
    ]
  }
)

boxes.append(
  {
    :name => "{{lab_name}}-ubuntu-server-2",
    :ip => "{{ip_range}}.52",
    :box => "bento/ubuntu-24.04",
    :os => "linux",
    :cpus => 2,
    :mem => 4000,
    :forwarded_port => [
      {:guest => 22, :host => 2252, :id => "ssh"}
    ]
  }
)

boxes.append(
  {
    :name => "{{lab_name}}-ubuntu-server-3",
    :ip => "{{ip_range}}.53",
    :box => "bento/ubuntu-24.04",
    :os => "linux",
    :cpus => 2,
    :mem => 4000,
    :forwarded_port => [
      {:guest => 22, :host => 2253, :id => "ssh"}
    ]
  }
)
