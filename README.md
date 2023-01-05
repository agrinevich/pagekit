# Pagekit

Static Website CMS

Pagekit is a server side SSG (static site generator). You don't need to have local installation and can access it from anywhere like normal CMS.

## 1. Setup server

  1. git (to pull updates from github)
  2. rsync (to deploy)
  3. sqlite3
  4. nginx
  5. certbot (for SSL)
  6. perl dependencies.

You can install perl dependencies in one of the following ways:

A) as Debian modules (recommended - easy to remove):

* libconst-fast-perl
* libdbd-sqlite3-perl
* libdbi-perl
* libplack-perl
* libtest-compile-perl
* libtext-xslate-perl
* libpath-tiny-perl
* libconfig-tiny-perl
* libfile-copy-recursive-perl
* libnumber-bytes-human-perl
* libarchive-zip-perl
* starman

B) as CPAN modules:

in project dir run 'cpanm --installdeps . --cpanfile cpanfile'

but no way to remove modules if you need.

## 2. Setup website

  1. add system user 'website' (if domain is 'website.com')
  2. create dir /home/website/spot
  3. git clone repo to this dir
  4. 'cd spot' and 'prove -l' to check dependencies
  5. mkdir /var/www/website.com
  6. chown -R website:website /var/www/website.com/
  7. chmod -R 755 /var/www/website.com
  8. setup /etc/nginx/conf.d/website.com.conf (example in repo)
  9. restart nginx
  10. now go to dir /var/www/website.com
  11. setup /var/www/website.com/launcher.conf
  12. setup /var/www/website.com/main.conf
  13. run './bin/launcher.pl --command=rsync'
  14. manually copy templates from /home/website/spot/tpl to /var/www/website.com/tpl
  15. run './bin/launcher.pl --command=init'
  16. create dirs 'log', 'tmp', 'html'
  17. run './bin/launcher.pl --command=start'
  18. update domain A-records to server IP (and wait until its in effect)
  19. certbot --nginx (read https://www.itzgeek.com/how-tos/linux/debian/how-to-install-lets-encrypt-ssl-certificate-for-nginx-on-debian-11.html )
  20. update /var/www/website.com/main.conf (https in site host)
  21. in browser open website.com/admin/ and enter your login and password
