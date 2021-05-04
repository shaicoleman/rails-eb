### al2-base
FROM docker.io/amazonlinux:2 AS al2-base

RUN --mount=type=cache,target=/var/cache/yum,sharing=locked \
  echo ' ===> Installing Percona repository' && \
  yum -y -q install https://repo.percona.com/yum/percona-release-latest.noarch.rpm && \
  echo ' ===> Installing eatmydata to speed up things' && \
  yum -y -q install libeatmydata

ENV LD_PRELOAD='/usr/lib64/libeatmydata.so'

RUN --mount=type=cache,target=/var/cache/yum,sharing=locked \
  echo ' ===> Running yum upgrade' && \
  yum -y -q upgrade


### al2-dev
FROM al2-base AS al2-dev

RUN --mount=type=cache,target=/var/cache/yum,sharing=locked \
  echo ' ===> Enabling epel/postgresql10 repos' && \
  amazon-linux-extras enable epel postgresql10 && \
  echo ' ===> Configuring EPEL repo' && \
  yum -y -q install epel-release && \
  echo ' ===> Configuring Node repo' && \
  (curl -sL https://rpm.nodesource.com/setup_14.x | bash -) && \
  echo ' ===> Configuring Yarn repo' && \
  (curl -sL https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo)

RUN --mount=type=cache,target=/var/cache/yum,sharing=locked \
  echo ' ===> Installing development tools' && \
  yum -y -q install gcc gcc-c++ git autoconf automake bzip2 make libtool file which && \
  echo ' ===> Installing Ruby dependencies' && \
  yum -y -q install openssl openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel ncurses-devel gmp-devel \
                    postgresql10-devel libsodium

### ruby
FROM al2-dev AS ruby
RUN \
  echo ' ===> Downloading ruby-build' && \
  git clone --depth=1 https://github.com/rbenv/ruby-build.git ~/ruby-build && \
  echo ' ===> Building ruby' && \
  RUBY_CONFIGURE_OPTS="--disable-install-doc --disable-jit-support --prefix=/opt/rubies/ruby-2.7.3 --enable-shared" ~/ruby-build/bin/ruby-build 2.7.3 /opt/rubies/ruby-2.7.3 && \
  rm -rf /opt/rubies/ruby-2.7.3/lib/ruby/gems/2.7.0/cache

### file
FROM al2-dev AS file
RUN --mount=type=cache,target=/var/cache/yum,sharing=locked \
  echo ' ===> Installing file dependencies' && \
  yum -y -q install rpm-build python2-devel python2-setuptools && \
  echo ' ===> Downloading file' && \
  mkdir -p ~/file-build && \
  cd ~/file-build && \
  FILE_SRPMS_URL="https://download-ib01.fedoraproject.org/pub/fedora/linux/releases/34/Everything/source/tree/Packages/f/file-5.39-5.fc34.src.rpm" && \
  curl -sSL "$FILE_SRPMS_URL" -o $(basename "$FILE_SRPMS_URL") && \
  echo ' ===> Build file RPM' && \
  rpmbuild --rebuild $(basename "$FILE_SRPMS_URL")

# ### app-base
# FROM al2-dev AS app-base
# COPY --chown=cffadmin:cffadmin --from=node $HOME/node $HOME/node
# COPY --chown=cffadmin:cffadmin --from=ruby $HOME/ruby $HOME/ruby
# ENV PATH="$HOME/.gem/ruby/2.6.0/bin:$HOME/ruby/bin:$HOME/node/bin:$HOME/file/bin:/usr/pgsql-10/bin:$PATH"

# RUN \
#   echo ' ===> Creating .gemrc' && \
#   (echo 'gem: --user-install --no-document' > ~/.gemrc) && \
#   echo ' ===> Uninstalling bundled gems' && \
#   gem uninstall --executables did_you_mean minitest net-telnet power_assert rake test-unit xmlrpc && \
#   echo ' ===> Updating bundler' && \
#   gem install bundler -v=2.1.4 --no-post-install-message && \
#   gem cleanup && \
#   rm -rf ~/.gem/specs ~/.gem/ruby/2.6.0/cache ~/ruby/lib/ruby/gems/2.6.0/cache

# ARG RAILS_ENV
# ENV RAILS_ENV="$RAILS_ENV"
# ARG NODE_ENV
# ENV NODE_ENV="$NODE_ENV"
# ENV SECRET_KEY_BASE="none"
# ENV DEVISE_SECRET_KEY="none"
# ENV ENCRYPTION_KEY="123456044debc6f6c43f856bbb12e9c5070c33c63510586e30a4c60c3ecadb26"


# ### ruby-bundle
# FROM app-base AS ruby-bundle

# COPY --chown=cffadmin:cffadmin Gemfile Gemfile.lock cashanalytics/
# RUN mkdir -p ~/cashanalytics/vendor/bundle/ruby/2.6.0
# RUN --mount=type=cache,uid=1000,gid=1000,target=/home/cffadmin/cashanalytics/vendor/bundle/ruby/2.6.0/cache,sharing=locked \
#   cd ~/cashanalytics && \
#   echo " ===> Removing unused groups from Gemfile" && \
#   perl -i -0pe "s/\ngroup((?!staging|production).)*? do.*?\n\s*end\s*/\n/sg" Gemfile && \
#   echo " ===> Running bundle install ($RAILS_ENV environment)" && \
#   bundle config --global jobs `nproc` && \
#   bundle install --path vendor/bundle --quiet


# ### yarn-packages
# FROM app-base AS yarn-packages
# COPY --chown=cffadmin:cffadmin package.json yarn.lock .npmrc cashanalytics/
# RUN mkdir -p ~/.cache/yarn
# RUN --mount=type=cache,uid=1000,gid=1000,target=/home/cffadmin/.cache/yarn,sharing=locked \
#   cd ~/cashanalytics && \
#   echo " ===> Removing devDependencies from packages.json" && \
#   perl -i -0pe "s/,\s+\"devDependencies[^}]+}//" package.json && \
#   echo " ===> yarn install" && \
#   yarn install --silent --frozen-lockfile --non-interactive


# # main
# FROM app-base
# USER root
# RUN --mount=type=cache,target=/var/cache/yum,sharing=locked \
#   echo ' ===> Installing wkhtmltopdf dependencies' && \
#   yum -y -q install fontconfig libXrender libXext libjpeg-turbo

# USER cffadmin
# COPY --chown=cffadmin:cffadmin --from=file $HOME/file $HOME/file
# COPY --chown=cffadmin:cffadmin --from=wkhtmltopdf $HOME/wkhtmltopdf $HOME/wkhtmltopdf
# COPY --chown=cffadmin:cffadmin --from=ruby-bundle $HOME/cashanalytics $HOME/cashanalytics
# COPY --chown=cffadmin:cffadmin --from=yarn-packages $HOME/cashanalytics $HOME/cashanalytics

# COPY --chown=cffadmin:cffadmin *.js config.ru Rakefile .browserslistrc cashanalytics/
# COPY --chown=cffadmin:cffadmin app cashanalytics/app/
# COPY --chown=cffadmin:cffadmin bin cashanalytics/bin/
# COPY --chown=cffadmin:cffadmin config cashanalytics/config/
# COPY --chown=cffadmin:cffadmin docker/rails/secrets.yml cashanalytics/config/
# COPY --chown=cffadmin:cffadmin docker/rails/database.yml cashanalytics/config/
# COPY --chown=cffadmin:cffadmin db cashanalytics/db/
# COPY --chown=cffadmin:cffadmin lib cashanalytics/lib/
# COPY --chown=cffadmin:cffadmin public/*.* cashanalytics/public/

# ENV LD_LIBRARY_PATH=$HOME/lib
# ENV PATH="$HOME/.gem/ruby/2.6.0/bin:$HOME/ruby/bin:$HOME/node/bin:$HOME/file/bin:$HOME/wkhtmltopdf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"


# RUN cd ~/cashanalytics; mkdir -p node_modules/.cache tmp/cache/assets tmp/cache/webpacker/babel-loader-node-modules
# RUN --mount=type=cache,uid=1000,gid=1000,target=/home/cffadmin/cashanalytics/node_modules/.cache,sharing=locked \
#     --mount=type=cache,uid=1000,gid=1000,target=/home/cffadmin/cashanalytics/tmp/cache/assets,sharing=locked \
#     --mount=type=cache,uid=1000,gid=1000,target=/home/cffadmin/cashanalytics/tmp/cache/webpacker/babel-loader-node-modules,sharing=locked \
#   cd ~/cashanalytics && \
#   mkdir -p tmp log && \
#   rm -f bin/yarn && \
#   echo " ===> rails assets:precompile" && \
#   bin/rails assets:precompile && \
#   rm -rf log/*

# RUN \
#   cd ~/cashanalytics && \
#   echo " ===> Cleaning up" && \
#   find vendor/ -name Gemfile.lock -delete && \
#   rm -rf config/local.rb public/aws-alb-healthcheck.html && \
#   cd ~/cashanalytics/vendor/bundle/ruby/2.6.0/gems && \
#   rm -rf rotp-*/doc \
#          jquery-rails-*/vendor/assets/javascripts/{jquery,jquery2,jquery3}.*
