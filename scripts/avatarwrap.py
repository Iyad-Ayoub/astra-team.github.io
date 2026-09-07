import os
import glob
from PIL import Image
import shutil

from google_images_search import GoogleImagesSearch

# you can provide API key and CX using arguments,
# or you can set environment variables: GCS_DEVELOPER_KEY, GCS_CX
gis = GoogleImagesSearch(os.environ['GCS_DEVELOPER_KEY'], os.environ['GCS_CX'])

# # define search params
# # option for commonly used search param are shown below for easy reference.
# # For param marked with '##':
# #   - Multiselect is currently not feasible. Choose ONE option only
# #   - This param can also be omitted from _search_params if you do not wish to define any value
# # _search_params = {
# #   'q': '...',
# #   'num': 5,
# #   'fileType': 'jpg|gif|png',
# #   'rights': 'cc_publicdomain|cc_attribute|cc_sharealike|cc_noncommercial|cc_nonderived',
# #   'safe': 'active|high|medium|off|safeUndefined',  ##
# #   'imgType': 'clipart|face|lineart|stock|photo|animated|imgTypeUndefined',  ##
# #   'imgSize': 'huge|icon|large|medium|small|xlarge|xxlarge|imgSizeUndefined',  ##
# #   'imgDominantColor': 'black|blue|brown|gray|green|orange|pink|purple|red|teal|white|yellow|imgDominantColorUndefined',
# #   ##
# #   'imgColorType': 'color|gray|mono|trans|imgColorTypeUndefined'  ##
# # }
# _search_params = {
#   'q': 'Jean-Marc Lasgouttes',
#   'num': 5,
#   # 'fileType': 'jpg|gif|png',
#   # 'rights': 'cc_publicdomain|cc_attribute|cc_sharealike|cc_noncommercial|cc_nonderived',
#   # 'safe': 'active|high|medium|off|safeUndefined',  ##
#   'imgType': 'face',  ##
#   # 'imgSize': 'huge|icon|large|medium|small|xlarge|xxlarge|imgSizeUndefined',  ##
#   # 'imgDominantColor': 'black|blue|brown|gray|green|orange|pink|purple|red|teal|white|yellow|imgDominantColorUndefined',
#   ##
#   # 'imgColorType': 'color|gray|mono|trans|imgColorTypeUndefined'  ##
# }
#
# # this will only search for images:
# # gis.search(search_params=_search_params)
#
# # this will search and download:
# # gis.search(search_params=_search_params, path_to_dir='/path/')
#
# # this will search, download and resize:
# gis.search(search_params=_search_params, path_to_dir='avatars', width=500, height=500)
#
# # # search first, then download and resize afterwards:
# # gis.search(search_params=_search_params)
# # for image in gis.results():
# #   image.url  # image direct url
# #   image.referrer_url  # image referrer url (source)
# #
# #   image.download('/path/')  # download image
# #   image.resize(500, 500)  # resize downloaded image
# #
# #   image.path  # downloaded local file path

def find_images(fullname, num=5):
  _search_params = {
    'q': fullname,
    'num': num,
    # 'fileType': 'jpg|gif|png',
    # 'rights': 'cc_publicdomain|cc_attribute|cc_sharealike|cc_noncommercial|cc_nonderived',
    # 'safe': 'active|high|medium|off|safeUndefined',  ##
    # 'imgType': 'face',  ##
    # 'imgSize': 'huge|icon|large|medium|small|xlarge|xxlarge|imgSizeUndefined',  ##
    # 'imgDominantColor': 'black|blue|brown|gray|green|orange|pink|purple|red|teal|white|yellow|imgDominantColorUndefined',
    ##
    # 'imgColorType': 'color|gray|mono|trans|imgColorTypeUndefined'  ##
  }

  path = os.path.join('avatars', fullname)
  if os.path.exists(path):
    shutil.rmtree(path)
  os.makedirs(os.path.join('avatars', fullname), exist_ok=True)
  gis.search(search_params=_search_params, path_to_dir=path, width=500, height=500)

  files = glob.glob(path + os.sep + "*.*")
  images = []
  for f in files:
    im = Image.open(f)
    images.append(im)

  return images


if __name__ == "__main__":
  images = find_images("Jean-Marc Lasgouttes")
  print(len(images))
