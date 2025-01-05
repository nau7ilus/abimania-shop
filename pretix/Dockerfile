FROM pretix/standalone:stable

USER root

RUN DJANGO_SETTINGS_MODULE= pip install -U git+https://github.com/nau7ilus/pretix-abimania-theme.git@main && \
    cd /pretix/src && \
    sudo -u pretixuser make production

USER pretixuser

ENTRYPOINT ["pretix"]
CMD ["all"]
