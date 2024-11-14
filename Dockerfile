# Usa a imagem base do Alpine
FROM alpine:latest

# Define o diretório de trabalho
WORKDIR /app

# Copia o script .sh para o contêiner
COPY wireguard.sh .

# Dá permissão de execução ao script
RUN chmod +x wireguard.sh

# Define o comando padrão para rodar o script
CMD ["./wireguard.sh"]
