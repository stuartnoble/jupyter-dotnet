#build with: docker build --build-arg base_image=jupyter/minimal-notebook -t pocki/minimal-dotnet:latest -t pocki/minimal-dotnet:20210523 .
#build with: docker build --build-arg base_image=jupyter/scipy-notebook -t pocki/scipy-dotnet:latest -t pocki/scipy-dotnet:20210523 .
#build with: docker build --build-arg base_image=jupyter/r-notebook -t pocki/r-dotnet:latest -t pocki/r-dotnet:20210523 .

ARG base_image=jupyter/minimal-notebook
FROM ${base_image} as base

# Install .NET CLI dependencies

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

WORKDIR ${HOME}

USER root
RUN apt-get update
RUN apt-get install -y curl

ENV \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip \
    # Opt out of telemetry until after we install jupyter when building the image, this prevents caching of machine id
    DOTNET_TRY_CLI_TELEMETRY_OPTOUT=true

# Install .NET CLI dependencies
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

ENV DOTNET_SDK_VERSION 6.0.302
# Install .NET Core SDK
RUN dotnet_sdk_version=6.0.302 \
    && curl -SL --output dotnet.tar.gz https://dotnetcli.azureedge.net/dotnet/Sdk/$dotnet_sdk_version/dotnet-sdk-$dotnet_sdk_version-linux-x64.tar.gz \
    && dotnet_sha512='ac1d124802ca035aa00806312460b371af8e3a55d85383ddd8bb66f427c4fabae75b8be23c45888344e13b283a4f9c7df228447c06d796a57ffa5bb21992e6a4' \
    && echo "$dotnet_sha512 dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -ozxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    # Trigger first run experience by running arbitrary cmd
    && dotnet help

# Copy notebooks
COPY ./samples/notebooks/ ${HOME}/Notebooks/

# Copy package sources
COPY ./NuGet.config ${HOME}/nuget.config

RUN chown -R ${NB_UID} ${HOME}
USER ${USER}

#Install nteract 
RUN pip install nteract_on_jupyter

# Install lastest build from main branch of Microsoft.DotNet.Interactive
RUN dotnet tool install -g Microsoft.dotnet-interactive 

ENV PATH="${PATH}:${HOME}/.dotnet/tools"
#RUN echo "$PATH"

#RUN dotnet --list-sdks

# Install kernel specs
RUN dotnet interactive jupyter install

# Enable telemetry once we install jupyter for the image
ENV DOTNET_TRY_CLI_TELEMETRY_OPTOUT=false

# Set root to Notebooks
WORKDIR ${HOME}/Notebooks/
