#include "image_processor.h"
#include <cmath>
#include <cstring>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <numeric>

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

static double calculateVariance(const std::vector<unsigned char>& data) {
    if (data.empty()) return 0.0;

    double sum = 0.0;
    double sumSq = 0.0;

    for (size_t i = 0; i < data.size(); i++) {
        double val = static_cast<double>(data[i]);
        sum += val;
        sumSq += val * val;
    }

    size_t n = data.size();
    double mean = sum / n;
    double variance = (sumSq / n) - (mean * mean);

    return variance;
}

static bool isAlreadyBinarized(const std::vector<unsigned char>& data) {
    if (data.empty()) return false;

    int uniqueValues = 0;
    bool hasZero = false;
    bool has255 = false;

    for (size_t i = 0; i < data.size(); i++) {
        unsigned char val = data[i];
        if (val == 0) {
            hasZero = true;
        } else if (val == 255) {
            has255 = true;
        } else {
            return false;
        }
    }

    return hasZero && has255;
}

static double calculateMean(const std::vector<unsigned char>& data) {
    if (data.empty()) return 0.0;

    double sum = 0.0;
    for (size_t i = 0; i < data.size(); i++) {
        sum += static_cast<double>(data[i]);
    }
    return sum / data.size();
}

static int calculateOtsuThreshold(const std::vector<unsigned char>& data) {
    if (data.empty()) return 128;

    int histogram[256] = {0};
    for (size_t i = 0; i < data.size(); i++) {
        histogram[data[i]]++;
    }

    size_t total = data.size();
    double sum = 0.0;
    for (int i = 0; i < 256; i++) {
        sum += i * histogram[i];
    }

    double sumB = 0.0;
    int wB = 0;
    double maxVariance = 0.0;
    int threshold = 128;

    for (int t = 0; t < 256; t++) {
        wB += histogram[t];
        if (wB == 0) continue;

        int wF = static_cast<int>(total) - wB;
        if (wF == 0) break;

        sumB += t * histogram[t];
        double mB = sumB / wB;
        double mF = (sum - sumB) / wF;
        double variance = wB * wF * (mB - mF) * (mB - mF);

        if (variance > maxVariance) {
            maxVariance = variance;
            threshold = t;
        }
    }

    return threshold;
}

static int calculateAdaptiveThreshold(const std::vector<unsigned char>& data, int width, int height, int blockSize) {
    if (data.empty() || width <= 0 || height <= 0) return 128;

    double globalMean = calculateMean(data);

    double localSum = 0.0;
    int count = 0;

    int half = blockSize / 2;
    for (int y = half; y < height - half; y++) {
        for (int x = half; x < width - half; x++) {
            localSum += data[y * width + x];
            count++;
        }
    }

    double localMean = (count > 0) ? (localSum / count) : globalMean;

    double alpha = 0.15;
    return static_cast<int>(alpha * localMean + (1 - alpha) * globalMean);
}

ImageData ImageProcessor::toGrayscale(const ImageData& input) {
    ImageData output;
    output.width = input.width;
    output.height = input.height;
    output.channels = 1;

    if (input.data.empty() || input.width <= 0 || input.height <= 0) {
        return output;
    }

    if (input.channels == 1) {
        output.data = input.data;
        return output;
    }

    output.data.resize(input.width * input.height);

    size_t inputChannels = input.channels;
    for (int y = 0; y < input.height; y++) {
        for (int x = 0; x < input.width; x++) {
            size_t inputIdx = (y * input.width + x) * inputChannels;
            size_t outputIdx = y * input.width + x;

            if (inputChannels >= 3) {
                int r = static_cast<int>(input.data[inputIdx]);
                int g = static_cast<int>(input.data[inputIdx + 1]);
                int b = static_cast<int>(input.data[inputIdx + 2]);

                int gray = (r * 299 + g * 587 + b * 114 + 500) / 1000;
                gray = std::max(0, std::min(255, gray));
                output.data[outputIdx] = static_cast<unsigned char>(gray);
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

    if (input.data.empty()) {
        return output;
    }

    if (isAlreadyBinarized(input.data)) {
        output.data = input.data;
        return output;
    }

    double variance = calculateVariance(input.data);
    if (variance < 100) {
        output.data = input.data;
        return output;
    }

    int adaptiveThreshold = calculateAdaptiveThreshold(input.data, input.width, input.height, 11);

    int useThreshold = (threshold <= 0 || threshold >= 255) ? adaptiveThreshold : threshold;

    output.data.resize(input.width * input.height);
    for (size_t i = 0; i < input.data.size(); i++) {
        output.data[i] = input.data[i] > useThreshold ? 255 : 0;
    }

    return output;
}

ImageData ImageProcessor::denoise(const ImageData& input, int kernelSize) {
    ImageData output;
    output.width = input.width;
    output.height = input.height;
    output.channels = input.channels;

    if (input.data.empty() || kernelSize < 3) {
        output.data = input.data;
        return output;
    }

    output.data.resize(input.width * input.height);

    if (input.channels == 1) {
        int half = kernelSize / 2;

        for (int y = 0; y < input.height; y++) {
            for (int x = 0; x < input.width; x++) {
                int sum = 0;
                int count = 0;

                for (int ky = -half; ky <= half; ky++) {
                    for (int kx = -half; kx <= half; kx++) {
                        int ny = std::max(0, std::min(input.height - 1, y + ky));
                        int nx = std::max(0, std::min(input.width - 1, x + kx));
                        sum += input.data[ny * input.width + nx];
                        count++;
                    }
                }

                output.data[y * input.width + x] = static_cast<unsigned char>(sum / count);
            }
        }
    } else {
        output.data = input.data;
    }

    return output;
}

ImageData ImageProcessor::preprocess(const ImageData& input, int threshold, int kernelSize) {
    if (input.data.empty() || input.width <= 0 || input.height <= 0) {
        return input;
    }

    ImageData grayscale = toGrayscale(input);

    if (grayscale.data.empty()) {
        return input;
    }

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
