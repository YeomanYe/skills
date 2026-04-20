## API

接口：`POST /api/html2image`

基础地址：`https://html2image.hanfangyuan.cn`

### 请求参数与作用

| 参数 | 必填 | 默认值 | 作用 |
| --- | --- | --- | --- |
| `html` | 是 | 无 | 需要渲染的 HTML 字符串。 |
| `image_type` | 否 | `png` | 输出格式，支持 `png` / `jpeg`。 |
| `device_scale_factor` | 否 | `2` | 设备像素比（DPR），值越大越清晰，体积通常更大。范围：`0 < value <= 4`。 |
| `viewport_width` | 否 | `1080` | 页面视口宽度（像素）。范围：`320-3840`。 |
| `viewport_height` | 否 | `1920` | 页面视口高度（像素）。范围：`320-3840`。 |
| `render_wait_ms` | 否 | `300` | 截图前额外等待时长（毫秒），用于等待图片/字体等异步资源。范围：`0-10000`。 |
| `element_id` | 否 | `null` | 指定截图元素 ID（不带 `#`）；为空时截整页。 |
| `element_padding` | 否 | `0` | 对 `element_id` 截图区域增加边距（像素）。 |

### 成功响应

```json
{
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "image_type": "png",
  "device_scale_factor": 2.0,
  "viewport_width": 1080,
  "viewport_height": 1920,
  "render_wait_ms": 300,
  "element_id": "card",
  "element_padding": 0
}
```

### 常见错误

- `400`: `element_id` 对应元素不存在
- `422`: 请求参数不合法
