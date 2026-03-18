# Simple Photo Album Website for Grandma

- Uses 'NanoGallery2': [https://nanogallery2.nanostudio.org](https://nanogallery2.nanostudio.org)
- Easy Operation:
  - Start docker container
  - Place photos/video/audio into Media folder
  - Click 'Admin' & web friendly versions created
- Blocks web crawlers & prying eyes
- Integrates with site analytics
- Good for elderly viewers (simple operation, no complicated controls)

Repositories:
- GitHub: https://github.com/mlefkon/pix
- DockerHub: https://hub.docker.com/repository/docker/mlefkon/pix-nanogallery2


## `docker build`
```bash
    ./build.sh
```

## `docker run`

### Environment Variables
- `PHOTO_PX_H`: Web-friendly photo height (default: 720px)
- `PHOTO_PX_W`: Web-friendly photo width (default: 1280px)
- `VIDEO_PX_H`: Web-friendly video height (default: 480px)
- `VIDEO_PX_W`: Web-friendly video width (default: 640px)
- `USER_ADMIN`="MyAdminUser" (default: anyone can access)
- `USER_GUEST_CSV`="UserA,UserB,UserC" (default: anyone can access)
    - Note: The 'UserX' here functions as both username and password (identical to username) for HTTP Basic Authentication.  This is not for real security, but rather to act as a block for web crawlers and casual browsers.  Different 'Users' can be set to make the login easy to remember for different groups or families.
- `SITE_TITLE`: Text to appear as title at top of page (default: "Pix Gallery")
- `INDEX_HTML_HEAD_TAG_INSERT`: Html text that will be inserted after the &lt;head&gt; tag of index.html, useful for Google Analytics, etc.
### Volumes
- `/www/media`: This should be a host mount so media files can easily be dumped in.
- `/www/cache`: This can be a host mount or docker volume where the web-friendly cache can be stored.

```bash
docker run -d --name pix \
    -p 8080:80 \
    -v /mystorage/for/media:/www/media \
    -v /mystorage/for/cache:/www/cache:rw \
    -e PHOTO_PX_H=720 \
    -e PHOTO_PX_W=1280 \
    -e VIDEO_PX_H=480 \
    -e VIDEO_PX_W=640 \
    -e USER_ADMIN="MyAdminUser" \
    -e USER_GUEST_CSV="UserA,UserB,UserC" \
    -e SITE_TITLE="My Site" \
    -e INDEX_HTML_HEAD_TAG_INSERT="<script src=https://www.googletagmanager.com ...>
          </script>"
    mlefkon/pix-nanogallery2
```