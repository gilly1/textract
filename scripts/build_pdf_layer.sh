mkdir -p pdf_layer/python
cat > build_pdf_layer.sh <<'EOF'
#!/bin/bash
set -e

# Run inside Amazon Linux 2 Docker image
docker run --rm -v "$PWD/pdf_layer":/var/task \
  amazonlinux:2 bash -c "
    yum install -y python3 python3-pip gcc make zlib-devel libjpeg-devel \
      && pip3 install --upgrade pip \
      && pip3 install pdf2image==1.16.3 Pillow>=9.0.0,<11.0.0 -t python \
      && echo '✅ Layer built in ./pdf_layer/python'
  "
EOF

chmod +x build_pdf_layer.sh
