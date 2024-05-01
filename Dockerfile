# Start from Ubuntu base image
FROM ubuntu:22.04

# Install sudo, socat, and supervisor
# sudo: for giving root access to appuser
# socat: for listening on 0.0.0.0 and forwarding to localhost. We
# do this because pgtemp cannot directly listen on 0.0.0.0 for security reasons.
# supervisor: it's a process manager that allows us to run both socat and pgtemp
# simulataneously withing the container.
RUN apt-get update && apt-get -y install sudo socat supervisor

# Create a directory for supervisor's log files
RUN mkdir -p /var/log/supervisor

# Copy supervisor configuration file
RUN echo '[supervisord]' > /etc/supervisor/conf.d/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '[program:pgtemp]' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'command=/home/appuser/.cargo/bin/pgtemp postgresql://pguser:pgpass@localhost:6544/tempdb' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'user=appuser' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '[program:socat]' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'command=/usr/bin/socat TCP-LISTEN:6543,fork,reuseaddr TCP:localhost:6544' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'user=appuser' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf

# Create appuser. The reason we're not continuing with root is
# because cargo throws some errors and we're not able to run
# pgtemp because of that.
ARG user=appuser
ARG group=appuser
ARG uid=2000
ARG gid=2000
RUN groupadd -g ${gid} ${group}
RUN useradd -u ${uid} -g ${group} -s /bin/bash -m ${user} # <--- the '-m' create a user home directory
RUN usermod -aG sudo appuser
# Configure nopassword for this users
RUN echo "appuser ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers
# Switch to user
USER ${uid}:${gid}

# Install PostgreSQL and PostgreSQL client
# adding DEBIAN_FRONTEND=noninteractive so that
# postgres does not show installation dialogs asking
# for userinput
RUN sudo apt-get update && \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-14 postgresql-client-14 build-essential

# Install Cargo & pgtemp (Rust package manager)
RUN sudo apt-get install -y curl && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    export PATH="$HOME/.cargo/bin:$PATH" && \
    cargo --version && \
    cargo install pgtemp --features cli

# add cargo bin and postgres initdb to path
ENV PATH="/usr/lib/postgresql/14/bin:$PATH"

USER postgres

# update postgres conf
RUN echo '# The time (in seconds) the connection needs to remain idle before TCP starts sending keepalive probes' >> /etc/postgresql/14/main/postgresql.conf && \
    echo 'tcp_keepalives_idle = 5' >> /etc/postgresql/14/main/postgresql.conf && \
    echo '# The time (in seconds) between individual keepalive probes.' >> /etc/postgresql/14/main/postgresql.conf && \
    echo 'tcp_keepalives_interval = 1' >> /etc/postgresql/14/main/postgresql.conf && \
    echo '# The maximum number of keepalive probes TCP should send before dropping the connection' >> /etc/postgresql/14/main/postgresql.conf && \
    echo 'tcp_keepalives_count = 5' >> /etc/postgresql/14/main/postgresql.conf && \
    echo '# the maximum amount of time that transmitted data may remain unacknowledged before the' >> /etc/postgresql/14/main/postgresql.conf && \
    echo '# kernel forcefully closes the connection' >> /etc/postgresql/14/main/postgresql.conf && \
    echo 'tcp_user_timeout = 5000' >> /etc/postgresql/14/main/postgresql.conf

# switch back to root for running supervisord
USER root

# Run supervisord, this starts both pgtemp that listens on localhost:6544 and socat that accepts
# connections from 0.0.0.0:6543 and forwards to pgtemp at localhost:6544
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
