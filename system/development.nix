{ config, pkgs, lib, ... }:
{

  environment.systemPackages = with pkgs; [
    vim
    sudo
    grub2
  ];

  warnings = [ "Development configuration active." ];

  services.openssh.enable = true;
  programs.mosh.enable = true;

  users.users.dev = {
    isNormalUser = true;
    home = "/home/dev";
    extraGroups = [ "wheel" "networkmanager" ];
    password = "123";

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC1sG8P7S/+SR2dI+R228AFfkN42/vV3D5KtfHZRXNShZwoXfgspLveIExWLX+D8IELJOb5ua41XGLSJhEh7t0kFy/mH5nPV6u2IQE+s7tpIynM8+hWZRLXcARuIRIcThDVqVxq0KjMeycFYZ/gNYG/J/bRAOVOXGSnkj9hVgLMIQIDmEnhJQXWu5Xzx3B4QkNwf+z6ytXd0FeKxJXDBovnRqOL70DpXHX+s1n1Dao6YKjfHPhR/M0r4n0yZ8FrEUeNm91/UHjeZzS+ETVpCrKPezXMAvwkCdsOQ41W62Mm/Ewun8+GIjo+dQ9elj4jBbNrxLojWWqBvvngr78xEtxI+IJWDIas/sQDHlRK+jKHqifepOrs1xogvS2akRXvXY3HwTUCLhQl7y3Em6TJN7P8GJu/OlhsRAl9TjWFzZVYhjGMW9WPs1kz6ZjvIze2KC3qQQv/bNuTQ0AmunGaBtfy2dEL3HmnsWwgmnoGHd4Pg0pTJdqxOqgx5fI6qRhX5Hk4MBUMvDACgdeAn0JsfLQOGtI+ODGrcY0C4GctaHZ8iUy7Wmg0LC100lteXRLgiso2O+Gx+RNoi/1lzgd0+AE06mx+b/+X7GvRbCeUCh1vnAjHQoXUlMbbwQwW9hpspAR9zZ4p9o30fJ7oNK9abJGmYO23qe6pyD5/UNXJ71nPWw== (none)"
    ];
  };

}
