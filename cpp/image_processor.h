#pragma once

#include <vector>
#include <string>

namespace imageproc {

struct ImageData {
    int width;
    int height;
    int channels;
    std::vector<unsigned char> data;
};

class ImageProcessor {
public:
    static ImageData loadFromFile(const std::string& filepath);

    static bool saveToFile(const ImageData& image, const std::string& filepath);

    static ImageData toGrayscale(const ImageData& input);

    static ImageData binarize(const ImageData& input, int threshold = 128);

    static ImageData denoise(const ImageData& input, int kernelSize = 3);

    static ImageData preprocess(const ImageData& input, int threshold = 128, int kernelSize = 3);

    static std::vector<unsigned char> toBase64(const ImageData& input);

    static ImageData fromBase64(const std::string& base64Str, int width, int height, int channels);
};

}
