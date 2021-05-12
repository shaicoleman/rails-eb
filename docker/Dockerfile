### al2-base
FROM docker.io/amazonlinux:2 AS al2-base

RUN --mount=type=cache,target=/var/cache/yum,sharing=locked \
  echo ' ===> Installing eatmydata ===' && \
  yum -y -q install \
    https://ca-downloads.s3-eu-west-1.amazonaws.com/eatmydata/libeatmydata-0.1-00.21.el7.centos.x86_64.rpm

ENV LD_PRELOAD='/usr/lib64/libeatmydata.so'

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
  yum -y -q install gcc gcc-c++ git autoconf automake bzip2 make libtool which p7zip xz tar \
    https://ca-downloads.s3-eu-west-1.amazonaws.com/file/file-5.39-5.amzn2.x86_64.rpm \
    https://ca-downloads.s3-eu-west-1.amazonaws.com/file/file-libs-5.39-5.amzn2.x86_64.rpm \
  echo ' ===> Installing Ruby dependencies' && \
  yum -y -q install openssl openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel ncurses-devel gmp-devel \
                    postgresql-devel libsodium && \
  echo ' ===> Installing nodejs/yarn' && \
  yum -y -q install nodejs yarn

### ruby
FROM al2-dev AS ruby
RUN \
  mkdir -p /opt/rubies && \
  curl -sSL https://ca-downloads.s3-eu-west-1.amazonaws.com/ruby/ruby-2.7.3.tar.xz | tar xJ -C /opt/rubies

# ### app-base
FROM al2-dev AS app-base
COPY --from=ruby /opt/rubies /opt/rubies
RUN \
  echo ' ===> Creating webapp user' && \
  adduser webapp && \
  echo ' ===> Creating /var/app/staging directory' && \
  mkdir -p /var/app/staging && \
  chown -R webapp:webapp /var/app/staging
USER webapp
WORKDIR /var/app/staging
ENV HOME=/home/webapp
ENV PATH="$HOME/.local/share/gem/ruby/2.7.0/bin:/opt/rubies/ruby-2.7.3/bin:$PATH"
RUN \
   echo ' ===> Creating .gemrc' && \
   (echo 'gem: --user-install --no-document' > ~/.gemrc)

### ruby-bundle
FROM app-base AS ruby-bundle

RUN --mount=type=cache,uid=1000,gid=1000,target=/home/webapp/local/share/gem/ruby/2.7.0/cache,sharing=locked \
  PATH="$HOME/.local/share/gem/ruby/2.7.0/bin:$PATH" && \
  echo " ===> Upgrading bundler" && \
  gem install bundler --silent

COPY --chown=webapp:webapp Gemfile Gemfile.lock /var/app/staging

RUN mkdir -p /var/app/staging/vendor/bundle
RUN --mount=type=cache,uid=1000,gid=1000,target=/var/app/staging/vendor/bundle,sharing=locked \
  PATH="$HOME/.local/share/gem/ruby/2.7.0/bin:$PATH" && \
  echo " ===> Configuring bundler" && \
  bundle config unset --local deployment && \
  bundle config set --local jobs 8 && \
  bundle config set --local path vendor/bundle && \
  bundle config set --local clean true && \
  export MAKE="make --jobs 8" && \
  echo " ===> Removing unused groups from Gemfile" && \
  perl -i -0pe 's/\ngroup((?!:staging|:production).)*? do.*?\n\s*end\s*/\n/sg' Gemfile && \
  echo " ===> Running bundle install" && \
  bundle install --quiet && \
  bundle config set --local deployment true && \
  echo " ===> Copying bundle" && \
  mkdir -p ~/build && \
  (tar -cf - --exclude 'vendor/bundle/ruby/2.7.0/cache' Gemfile Gemfile.lock .bundle vendor/bundle | tar -xC ~/build)

### yarn-packages
FROM app-base AS yarn-packages
COPY --chown=webapp:webapp package.json yarn.lock .npmrc /var/app/staging
RUN mkdir -p ~/.cache/yarn /var/app/staging/node_modules
RUN --mount=type=cache,uid=1000,gid=1000,target=/home/webapp/.cache/yarn,sharing=locked \
    --mount=type=cache,uid=1000,gid=1000,target=/var/app/staging/node_modules,sharing=locked \
  echo " ===> yarn install" && \
  yarn install --silent --frozen-lockfile --non-interactive --production && \
  yarn autoclean && \
  echo " ===> Copying node_modules" && \
  mkdir -p ~/build && \
  cp -r package.json yarn.lock node_modules ~/build/

# app-rails
FROM app-base
COPY --chown=root:root --from=ruby /opt/rubies /opt/rubies
COPY --chown=webapp:webapp --from=ruby-bundle /home/webapp/build .
COPY --chown=webapp:webapp --from=yarn-packages /home/webapp/build .
COPY --chown=webapp:webapp *.js* config.ru Rakefile .browserslistrc .
COPY --chown=webapp:webapp app app/
COPY --chown=webapp:webapp bin bin/
COPY --chown=webapp:webapp config config/
COPY --chown=webapp:webapp db db/
COPY --chown=webapp:webapp lib lib/
USER webapp

ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV SECRET_KEY_BASE="none"
ENV DEVISE_SECRET_KEY="none"
ENV ENCRYPTION_KEY="123456044debc6f6c43f856bbb12e9c5070c33c63510586e30a4c60c3ecadb26"

RUN mkdir -p node_modules/.cache tmp/cache/assets tmp/cache/webpacker/babel-loader-node-modules
RUN --mount=type=cache,uid=1000,gid=1000,target=/var/app/staging/node_modules/.cache,sharing=locked \
    --mount=type=cache,uid=1000,gid=1000,target=/var/app/staging/tmp/cache/assets,sharing=locked \
    --mount=type=cache,uid=1000,gid=1000,target=/var/app/staging/tmp/cache/webpacker/babel-loader-node-modules,sharing=locked \
    echo " ===> rails assets:precompile" && \
    rm -f bin/yarn && \
    bin/rails assets:precompile

COPY --chown=webapp:webapp Procfile cron.yaml .
COPY --chown=webapp:webapp public/*.* public/

RUN \
  mkdir -p ~/build && \
  7za -bd -snl -mm=Deflate -xr!node_modules -xr!log/* a ~/build/app.zip

# RUN \
#   cd ~/cashanalytics && \
#   echo " ===> Cleaning up" && \
#   find vendor/ -name Gemfile.lock -delete && \
#   rm -rf config/local.rb public/aws-alb-healthcheck.html && \
#   cd ~/cashanalytics/vendor/bundle/ruby/2.6.0/gems && \
#   rm -rf rotp-*/doc \
#          jquery-rails-*/vendor/assets/javascripts/{jquery,jquery2,jquery3}.*
