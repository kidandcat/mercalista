package scanner

import (
	"bytes"
	"fmt"
	"image"
	_ "image/png"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/oned"
)

func Scan(imgData []byte) string {
	// open and decode image file
	r := bytes.NewReader(imgData)
	img, format, err := image.Decode(r)
	if err != nil {
		return err.Error()
	}
	fmt.Println("format:", format)

	// prepare BinaryBitmap
	bmp, err := gozxing.NewBinaryBitmapFromImage(img)
	if err != nil {
		return err.Error()
	}

	// decode image
	eanReader := oned.NewEAN13Reader()
	result, err := eanReader.Decode(bmp, nil)
	if err != nil {
		return err.Error()
	}

	return result.GetText()
}
