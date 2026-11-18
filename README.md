# Nairobi Delivery Time Prediction

## Mission and Problem

My mission is to make last-mile delivery reliable and affordable across East Africa so small businesses can grow.
In Nairobi, customers and businesses rarely know when a motorbike delivery will actually arrive, which wastes time and erodes trust.
This project predicts the delivery time from pick-up to drop-off using real Sendy orders, so logistics platforms can give customers accurate arrival estimates and plan their riders better.

## Dataset

The data comes from the Sendy Logistics Challenge on Zindi: real, anonymised motorbike delivery orders made on the Sendy platform in Nairobi, Kenya, with order details, distance, timing and rider statistics (21,201 orders and 960 riders).
Source: https://zindi.africa/competitions/sendy-logistics-challenge/data

## Public API (Swagger UI)

https://nairobi-delivery-time-api.onrender.com/docs

## Video Demo

_Coming soon_

## How to Run the Mobile App

The app connects to the live API, so no local server is needed.

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and set up an Android emulator (or connect an Android phone with USB debugging on).
2. Clone the repository and open the app folder:
   ```bash
   git clone https://github.com/T-Sylivie/linear_regression_model.git
   cd linear_regression_model/summative/FlutterApp
   ```
3. Install the dependencies:
   ```bash
   flutter pub get
   ```
4. Start the emulator, then run the app:
   ```bash
   flutter run
   ```
5. The fields come filled with an example order. Tap **Predict** to get the estimated delivery time, or change a value to see the error messages. The first request can take up to a minute while the free server wakes up.
