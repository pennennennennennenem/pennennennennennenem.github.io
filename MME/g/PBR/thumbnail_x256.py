from PIL import Image
import sys
import os
i=Image.open(sys.argv[1]).convert('RGB')
i.thumbnail((256,256*i.size[1]/i.size[0]))
i.save(os.path.splitext(sys.argv[1])[0] + '_s.jpg')