Dockerfile used to create image run by kakarot self hosted github runner:

- `nodejs 16.x`: github action dependency
- `python 3.9`: kakarot dependency
- `git & zstd`: foundry dependencies

To build the image:

```bash
docker build -t YOUR_DOCKER_HUB_USER/kakarot-builder:latest .
```

To publish your image on docker hub:

```bash
docker push YOUR_DOCKER_HUB_USER/kakarot-builder:latest
```
