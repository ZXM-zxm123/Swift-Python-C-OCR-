#include "image_processor.h"
#include <cmath>
#include <cstring>
#include <fstream>
#include <sstream>
#include <algorithm>

namespace imageproc {

static const char BASE64_TABLE[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static std::string base64Encode(const unsigned char* data, size_t length) {
    std::string result;
    int i = 0;
    int j = 0;
    unsigned char charArray3[3];
    unsigned char charArray4[4];

    while (length--) {
        charArray3[i++] = *(data++);
        if (i == 3) {
            charArray4[0] = (charArray3[0] & 0xfc) >> 2;
            charArray4[1] = ((charArray3[0] & 0x03) << 4) + ((charArray3[1] & 0xf0) >> 4);
            charArray4[2] = ((charArray3[1] & 0x0f) << 2) + ((charArray3[2] & 0xc0) >> 6);
            charArray4[3] = charArray3[2] & 0x3f;

            for(i = 0; i < 4; i++) {
                result += BASE64_TABLE[charArray4[i]];
            }
            i = 0;
        }
    }

    if (i) {
        for(j = i; j < 3; j++) {
            charArray3[j] = '\0';
        }
        charArray4[0] = (charArray3[0] & 0xfc) >> 2;
        charArray4[1] = ((charArray3[0] & 0x03) << 4) + ((charArray3[1] & 0xf0) >> 4);
        charArray4[2] = ((charArray3[1] & 0x0f) << 2) + ((charArray3[2] & 0xc0) >> 6);

        for (j = 0; j < i + 1; j++) {
            result += BASE64_TABLE[charArray4[j]];
        }
        while((i++ < 3)) {
            result += '=';
        }
    }

    return result;
}

static std::vector<unsigned char> base64Decode(const std::string& input) {
    std::vector<unsigned char> result;
    int len = input.length();
    int i = 0;
    int j = 0;
    int in = 0;
    unsigned char charArray4[4], charArray3[3];

    while (len-- && (input[in] != '=') && isalnum(input[in]) || input[in] == '+' || input[in] == '/') {
        charArray4[i++] = input[in]; in++;
        if (i == 4) {
            for (i = 0; i < 4; i++) {
                charArray4[i] = static_cast<unsigned char>(std::string(BASE64_TABLE).find(charArray4[i]));
            }
            charArray3[0] = (charArray4[0] << 2) + ((charArray4[1] & 0x30) >> 4);
            charArray3[1] = ((charArray4[1] & 0xf) << 4) + ((charArray4[2] & 0x3c) >> 2);
            charArray3[2] = ((charArray4[2] & 0x3) << 6) + charArray4[3];

            for (i = 0; i < 3; i++) {
                result.push_back(charArray3[i]);
            }
            i = 0;
        }
    }

    if (i) {
        for (j = 0; j < i; j++) {
            charArray4[j] = static_cast<unsigned char>(std::string(BASE64_TABLE).find(charArray4[j]));
        }
        charArray3[0] = (charArray4[0] << 2) + ((charArray4[1] & 0x30) >> 4);
        charArray3[1] = ((charArray4[1] & 0xf) << 4) + ((charArray4[2] & 0x3c) >> 2);

        for (j = 0; j < i - 1; j++) {
            result.push_back(charArray3[j]);
        }
    }

    return result;
}

ImageData ImageProcessor::loadFromFile(const std::string& filepath) {
    ImageData result;
    std::ifstream file(filepath, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        return result;
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::vector<char> buffer(size);
    if (file.read(buffer.data(), size)) {
        result.width = 0;
        result.height = 0;
        result.channels = 3;
        result.data.assign(buffer.begin(), buffer.end());
    }

    return result;
}

bool ImageProcessor::saveToFile(const ImageData& image, const std::string& filepath) {
    std::ofstream file(filepath, std::ios::binary);
    if (!file.is_open()) {
        return false;
    }
    file.write(reinterpret_cast<const char*>(image.data.data()), image.data.size());
    return file.good();
}

ImageData ImageProcessor::toGrayscale(const ImageData& input) {
    ImageData output;
    output.width = input.width;
    output.height = input.height;
    output.channels = 1;

    size_t inputChannels = input.channels;
    output.data.resize(input.width * input.height);

    for (int y = 0; y < input.height; y++) {
        for (int x = 0; x < input.width; x++) {
            size_t inputIdx = (y * input.width + x) * inputChannels;
            size_t outputIdx = y * input.width + x;

            if (inputChannels >= 3) {
                unsigned char r = input.data[inputIdx];
                unsigned char g = input.data[inputIdx + 1];
                unsigned char b = input.data[inputIdx + 2];
                output.data[outputIdx] = static_cast<unsigned char>(0.299 * r + 0.587 * g + 0.114 * b);
            } else {
                output.data[outputIdx] = input.data[inputIdx];
            }
        }
    }

    return output;
}

ImageData ImageProcessor::binarize(const ImageData& input, int threshold) {
    ImageData output;
    output.width = input.width;
    output.height = input.height;
    output.channels = 1;
    output.data.resize(input.width * input.height);

    for (size_t i = 0; i < input.data.size(); i++) {
        output.data[i] = input.data[i] > threshold ? 255 : 0;
    }

    return output;
}

ImageData ImageProcessor::denoise(const ImageData& input, int kernelSize) {
    ImageData output;
    output.width = input.width;
    output.height = input.height;
    output.channels = input.channels;
    output.data = input.data;

    int half = kernelSize / 2;
    std::vector<unsigned char> result = input.data;

    for (int y = half; y < input.height - half; y++) {
        for (int x = half; x < input.width - half; x++) {
            int sum = 0;
            int count = 0;

            for (int ky = -half; ky <= half; ky++) {
                for (int kx = -half; kx <= half; kx++) {
                    int ny = y + ky;
                    int nx = x + kx;
                    if (ny >= 0 && ny < input.height && nx >= 0 && nx < input.width) {
                        sum += input.data[ny * input.width + nx];
                        count++;
                    }
                }
            }

            int avg = sum / count;
            result[y * input.width + x] = static_cast<unsigned char>(avg);
        }
    }

    output.data = result;
    return output;
}

ImageData ImageProcessor::preprocess(const ImageData& input, int threshold, int kernelSize) {
    ImageData grayscale = toGrayscale(input);
    ImageData denoised = denoise(grayscale, kernelSize);
    ImageData binarized = binarize(denoised, threshold);
    return binarized;
}

std::vector<unsigned char> ImageProcessor::toBase64(const ImageData& input) {
    std::string encoded = base64Encode(input.data.data(), input.data.size());
    return std::vector<unsigned char>(encoded.begin(), encoded.end());
}

ImageData ImageProcessor::fromBase64(const std::string& base64Str, int width, int height, int channels) {
    ImageData output;
    output.width = width;
    output.height = height;
    output.channels = channels;

    std::vector<unsigned char> decoded = base64Decode(base64Str);
    output.data = decoded;

    return output;
}

}
