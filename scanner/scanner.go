package scanner

import (
	"bytes"
	"fmt"
	"image"
	_ "image/png" // image coded

	"github.com/disintegration/imaging"
	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/oned"
)

// Scan scans image for barcodes
func Scan(imgData []byte) string {
	r := bytes.NewReader(imgData)
	defer r.Reset(imgData)
	img, format, err := image.Decode(r)
	if err != nil {
		return err.Error()
	}
	fmt.Println("format:", format)

	var s string
	for i := 0; i < 6; i++ {
		s, err = scanImage(img)
		if err == nil {
			return s
		}
		img = imaging.Rotate90(img)
	}

	return ""
}

func scanImage(img image.Image) (string, error) {
	// prepare BinaryBitmap
	bmp, err := gozxing.NewBinaryBitmapFromImage(img)
	if err != nil {
		return "", err
	}

	// decode image
	eanReader := oned.NewEAN13Reader()
	defer eanReader.Reset()
	result, err := eanReader.Decode(bmp, nil)
	if err != nil {
		return "", err
	}

	return result.GetText(), nil
}
