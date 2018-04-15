# PLMediaKit

## Abstract
* Photo Selection
* Video Recording、Selection、Editing

## Support

iOS8.0+

## Feature

1. photo shoot, local photo selection, picture preview (support for gesture scaling and super long image).
3. video record, support flash and camera flip.
4. video clip、watermark、compression transcoding.
5. support iCloud video、gif file.

## Usage

```
PLMediaPickerViewController *vc = [[PLMediaPickerViewController alloc] init];
vc.maxNumber = 6; // the number of images
vc.type = PickerTypeImage;
[vc callBackImagesData:^(NSArray *imagesData) {
    NSLog(@"%@", imagesData);
} error:^(NSError *error) {
    NSLog(@"%@", error.localizedDescription);
}];
[self presentViewController:vc animated:YES completion:nil];
```

## License

PLMediaKit is available under the MIT license. See the LICENSE file for more info.

## Contact

Email : pauleyliu@gmail.com

