# PLMediaKit
照片选取和视频录制、选取、剪辑框架

## 支持版本

iOS8.0+

## 主要功能

1. 照片拍摄、本地选图、图片预览（支持手势缩放，支持超长图）。
3. 视频录制，支持闪光灯和镜头翻转。
4. 视频剪辑、水印、压缩转码。
5. 支持 iCloud 视频、GIF 图。

## 项目接入

PLMediaPickerViewController *vc = [[PLMediaPickerViewController alloc] init];
vc.maxNumber = 6; //选取图片数量
vc.type = PickerTypeImage;
[vc callBackImagesData:^(NSArray *imagesData) {
    NSLog(@"%@", imagesData);
} error:^(NSError *error) {
    NSLog(@"%@", error.localizedDescription);
}];
[self presentViewController:vc animated:YES completion:nil];

## License

YTKNetwork is available under the MIT license. See the LICENSE file for more info.

