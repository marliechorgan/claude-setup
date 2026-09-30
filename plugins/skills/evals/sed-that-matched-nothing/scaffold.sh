#!/bin/sh
set -e
mkdir -p configs
printf 'model: small\nlearning_rate: 0.001\nsteps: 5000\n' > configs/a.yaml
printf 'model: base\nlearning_rate: 1e-3\nsteps: 8000\n' > configs/b.yaml
printf '#!/bin/sh\necho "launched with $(grep learning_rate configs/*.yaml | tr "\\n" " ")" > launch.log\n' > launch.sh
chmod +x launch.sh
