FROM julia:0.6.2

RUN useradd -m user
RUN apt-get update && apt-get install -y unzip make gcc

WORKDIR /home/user/.julia/v0.6/DandelionWebSockets
RUN chown -R user:user /home/user/.julia

USER user

COPY . /home/user/.julia/v0.6/DandelionWebSockets

RUN julia -e 'Pkg.update("DandelionWebSockets")'

CMD ["julia", "test/smoke/clientecho/client.jl"]