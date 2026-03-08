# See https://aka.ms/customizecontainer to learn how to customize your debug container
# and how Visual Studio uses this Dockerfile to build your images for faster debugging.

# Runtime base image
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
USER $APP_UID
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# Restore stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS restore
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Copy csproj files first for better layer caching
COPY ["DotnetWebApi.Api/DotnetWebApi.Api.csproj", "DotnetWebApi.Api/"]
COPY ["DotnetWebApi.Api.Tests/DotnetWebApi.Api.Tests.csproj", "DotnetWebApi.Api.Tests/"]

RUN dotnet restore "./DotnetWebApi.Api/DotnetWebApi.Api.csproj"
RUN dotnet restore "./DotnetWebApi.Api.Tests/DotnetWebApi.Api.Tests.csproj"

# Build stage
FROM restore AS build
ARG BUILD_CONFIGURATION=Release
COPY . .
WORKDIR /src/DotnetWebApi.Api
RUN dotnet build "./DotnetWebApi.Api.csproj" -c $BUILD_CONFIGURATION -o /app/build --no-restore

# Test stage
FROM build AS test
ARG BUILD_CONFIGURATION=Release
WORKDIR /src/DotnetWebApi.Api.Tests
RUN dotnet test "./DotnetWebApi.Api.Tests.csproj" -c $BUILD_CONFIGURATION --no-restore --no-build

# Publish stage
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
WORKDIR /src/DotnetWebApi.Api
RUN dotnet publish "./DotnetWebApi.Api.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false --no-restore

# Final runtime image
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "DotnetWebApi.Api.dll"]